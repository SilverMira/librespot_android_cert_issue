use std::sync::Arc;

use librespot::{
    core::{spotify_id::SpotifyItemType, Session, SessionConfig, SpotifyId},
    discovery::Credentials,
    playback::{
        audio_backend,
        config::{AudioFormat, PlayerConfig},
        mixer::NoOpVolume,
        player::Player,
    },
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
