pub mod api;
mod frb_generated;

#[cfg(target_os = "android")]
#[no_mangle]
pub extern "system" fn Java_com_example_frb_1base_RustJniContext_initAndroid(
    env: jni::JNIEnv,
    _class: jni::objects::JClass,
    ctx: jni::objects::JObject,
) -> jni::sys::jint {
    static INIT: std::sync::Once = std::sync::Once::new();

    INIT.call_once(|| {
        android_logger::init_once(
            android_logger::Config::default()
                .with_max_level(log::LevelFilter::Trace) // limit log level
                .with_tag("test_librespot"),
        );
    });
    let result = setup_android(env, ctx);
    if let Err(err) = result {
        log::error!("Error during setup_android: {:?}", err);
        -1
    } else {
        0
    }
}

#[cfg(target_os = "android")]
fn setup_android(
    env: jni::JNIEnv,
    android_context: jni::objects::JObject,
) -> jni::errors::Result<()> {
    use std::ffi::c_void;

    use log::debug;
    let vm = env.get_java_vm()?;
    let vm_ptr = vm.get_java_vm_pointer() as *mut c_void;
    let context_ptr = android_context.into_inner() as *mut c_void;

    debug!("vm_ptr: {:?}, context_ptr: {:?}", vm_ptr, context_ptr);
    unsafe {
        ndk_context::initialize_android_context(vm_ptr, context_ptr);
    }

    setup_rustls_platform_verifier()?;
    Ok(())
}

#[cfg(target_os = "android")]
fn setup_rustls_platform_verifier() -> jni::errors::Result<()> {
    use log::debug;

    struct Runtime {
        ctx: ndk_context::AndroidContext,
        vm: jni::JavaVM,
        context: jni::objects::GlobalRef,
        class_loader: jni::objects::GlobalRef,
    }
    impl rustls_platform_verifier::android::Runtime for Runtime {
        fn java_vm(&self) -> &jni::JavaVM {
            &self.vm
        }

        fn context(&self) -> &jni::objects::GlobalRef {
            &self.context
        }

        fn class_loader(&self) -> &jni::objects::GlobalRef {
            &self.class_loader
        }
    }

    unsafe impl Send for Runtime {}
    unsafe impl Sync for Runtime {}

    static RUNTIME: once_cell::sync::OnceCell<Runtime> = once_cell::sync::OnceCell::new();
    let runtime: jni::errors::Result<&Runtime> = RUNTIME.get_or_try_init(|| {
        debug!("Initializing rustls platform verifier runtime");
        let ctx = ndk_context::android_context();

        let context: jni::objects::JObject = {
            let context = ctx.context() as jni::sys::jobject;
            context.into()
        };
        debug!("Got android context: {:?}", context);

        let vm = unsafe { jni::JavaVM::from_raw(ctx.vm().cast()) }?;
        debug!("Got VM");
        let env = vm.attach_current_thread_as_daemon()?;
        debug!("Attached thread as daemon");

        let loader =
            env.call_method(context, "getClassLoader", "()Ljava/lang/ClassLoader;", &[])?;

        debug!("Got class loader");
        let loader = jni::objects::JObject::try_from(loader)?;

        debug!("Cast class loader");

        let context = env.new_global_ref(context)?;
        debug!("Pinned android context");

        let loader = env.new_global_ref(loader)?;
        debug!("Pinned class loader");

        Ok(Runtime {
            ctx,
            vm,
            context,
            class_loader: loader,
        })
    });

    rustls_platform_verifier::android::init_external(runtime?);
    Ok(())
}
