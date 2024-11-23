use std::sync::Arc;

use librespot::{
    audio::{AudioDecrypt, AudioFile},
    core::{spotify_id::SpotifyItemType, Session, SessionConfig, SpotifyId},
    discovery::Credentials,
    metadata::audio::AudioItem,
    playback::{
        audio_backend,
        config::{AudioFormat, PlayerConfig},
        mixer::NoOpVolume,
        player::Player,
    },
};
use rspotify::{
    prelude::{BaseClient as _, OAuthClient},
    AuthCodePkceSpotify,
};

#[flutter_rust_bridge::frb(sync)] // Synchronous mode for simplicity of the demo
pub fn greet(name: String) -> String {
    format!("Hello, {name}!")
}

#[flutter_rust_bridge::frb(opaque)]
pub struct LibrespotPlayer {
    player: Arc<Player>,
}

impl LibrespotPlayer {
    pub async fn new(access_token: String, track_id: String) -> anyhow::Result<LibrespotPlayer> {
        let session_config = SessionConfig::default();
        let player_config = PlayerConfig::default();
        let audio_format = AudioFormat::default();

        let credentials = Credentials::with_access_token(access_token);

        let mut track = SpotifyId::from_base62(&track_id)?;
        track.item_type = SpotifyItemType::Track;

        let session = Session::new(session_config, None);
        log::trace!("Connecting to librespot");
        if let Err(err) = session.connect(credentials, false).await {
            log::error!("Error connecting to librespot: {err:?}");
            Err(err)?;
        }

        log::trace!("Try getting audio item");
        let audio_item = AudioItem::get_file(&session, track).await?;

        let mut audio_files = audio_item.files.iter();
        let audio_stream = loop {
            let Some((format, file_id)) = audio_files.next() else {
                break None;
            };

            log::trace!("Trying to load audio file: format={format:?} file_id={file_id:?}");

            let encrypted_file = AudioFile::open(&session, *file_id, 40 * 1024).await;

            let file = match encrypted_file {
                Ok(file) => file,
                Err(err) => {
                    log::error!("Error opening audio file: err={err:?}");
                    continue;
                }
            };

            let key = match session.audio_key().request(track, *file_id).await {
                Ok(key) => Some(key),
                Err(_) => {
                    println!("Failed to get audio key for track={track:?} file={file_id:?}");
                    None
                }
            };

            break Some(AudioDecrypt::new(key, file));
        };

        log::trace!("Audio stream available: {}", audio_stream.is_some());

        log::trace!("Finding audio backend");
        let backend = audio_backend::find(None).unwrap();

        log::trace!("Creating player");
        let player = Player::new(player_config, session, Box::new(NoOpVolume), move || {
            backend(None, audio_format)
        });

        log::trace!("Start playing");
        player.load(track, true, 0);

        Ok(LibrespotPlayer { player })
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn play(&self) {
        self.player.play();
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn pause(&self) {
        self.player.pause();
    }
}

#[flutter_rust_bridge::frb(opaque)]
pub struct PkceOAuthSession {
    client: AuthCodePkceSpotify,
}

pub struct OAuthAuthorizeUrl {
    pub auth_url: String,
    pub redirect_url: String,
}

impl PkceOAuthSession {
    fn credentials() -> rspotify::Credentials {
        let session_config = SessionConfig::default();
        rspotify::Credentials::new_pkce(&session_config.client_id)
    }

    fn oauth(client_id: &str) -> rspotify::OAuth {
        rspotify::OAuth {
            redirect_uri: Self::client_id_redirect_uri(client_id),
            scopes: rspotify::scopes!("streaming"),
            ..Default::default()
        }
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn new() -> Self {
        let credentials = Self::credentials();
        let oauth = Self::oauth(&credentials.id);
        Self {
            client: AuthCodePkceSpotify::new(credentials, oauth),
        }
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn from_token_json(token: String) -> anyhow::Result<Self> {
        let token = serde_json::from_str(&token)?;
        let credentials = Self::credentials();
        // let oauth = Self::oauth(&credentials.id);
        let client = {
            let mut client = rspotify::AuthCodePkceSpotify::from_token(token);
            client.creds = credentials;
            // client.oauth = oauth;
            client
        };

        Ok(Self { client })
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn auth_url(&mut self) -> anyhow::Result<OAuthAuthorizeUrl> {
        Ok(OAuthAuthorizeUrl {
            auth_url: self.client.get_authorize_url(None)?,
            redirect_url: self.client.oauth.redirect_uri.clone(),
        })
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn client_id_redirect_uri(client_id: &str) -> String {
        const KEYMASTER_CLIENT_ID: &str = "65b708073fc0480ea92a077233ca87bd";
        const ANDROID_CLIENT_ID: &str = "9a8d2f0ce77a4e248bb71fefcb557637";
        const IOS_CLIENT_ID: &str = "58bd3c95768941ea9eb4350aaa033eb3";
        match client_id {
            ANDROID_CLIENT_ID => "https://auth-callback.spotify.com/r/android/music/login",
            // ANDROID_CLIENT_ID => "spotify-auth-music://callback/r/android/music/login",
            _ => "http://127.0.0.1:8877/login",
        }
        .to_owned()
    }

    pub async fn callback(&mut self, code: String) -> anyhow::Result<()> {
        self.client.request_token(&code).await?;

        Ok(())
    }

    pub async fn access_token(&self) -> anyhow::Result<Option<String>> {
        let token = self.token().await?;

        Ok(token.map(|t| t.access_token))
    }

    pub async fn refresh_token(&self) -> anyhow::Result<Option<String>> {
        self.client.refresh_token().await?;

        self.access_token().await
    }

    async fn token(&self) -> anyhow::Result<Option<rspotify::Token>> {
        self.client.auto_reauth().await?;

        let new_token = self.client.token.lock().await.unwrap().clone();

        Ok(new_token)
    }

    pub async fn token_json(&self) -> anyhow::Result<Option<String>> {
        let Some(token) = self.token().await? else {
            return Ok(None);
        };
        let json = serde_json::to_string_pretty(&token)?;

        Ok(Some(json))
    }
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Default utilities - feel free to customize
    flutter_rust_bridge::setup_default_user_utils();

    // Initialize logger
    #[cfg(target_os = "android")]
    let _ = android_logger::init_once(
        android_logger::Config::default()
            .with_max_level(log::LevelFilter::Trace) // limit log level
            .with_tag("test_librespot"),
    );

    #[cfg(not(target_os = "android"))]
    let _ = env_logger::try_init();
}
