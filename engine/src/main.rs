use std::io::Write;
use std::path::PathBuf;
use std::sync::atomic::{AtomicI32, Ordering};
use std::time::Instant;

use anyhow::Result;
use clap::{Parser, ValueEnum};
use ocr_rs::{OcrEngine, OcrEngineConfig, RecognizeOptions, RotatedTextMode};
use serde::Serialize;

/// MNN prints capability lines to stdout. Mute fd 1 around engine lifetime so
/// JSON/text on stdout stays a single payload. fflush(NULL) before restore so
/// C stdio does not dump the buffered line after we give stdout back.
static SAVED_STDOUT_FD: AtomicI32 = AtomicI32::new(-1);

fn mute_stdout() {
    let _ = std::io::stdout().flush();
    unsafe {
        if SAVED_STDOUT_FD.load(Ordering::SeqCst) >= 0 {
            return;
        }
        libc::fflush(std::ptr::null_mut());
        let saved = libc::dup(1);
        if saved < 0 {
            return;
        }
        #[cfg(windows)]
        let path: &[u8] = b"NUL\0";
        #[cfg(not(windows))]
        let path: &[u8] = b"/dev/null\0";
        let nullfd = libc::open(path.as_ptr() as *const libc::c_char, libc::O_WRONLY);
        if nullfd < 0 {
            libc::close(saved);
            return;
        }
        libc::dup2(nullfd, 1);
        libc::close(nullfd);
        SAVED_STDOUT_FD.store(saved, Ordering::SeqCst);
    }
}

fn unmute_stdout() {
    unsafe {
        libc::fflush(std::ptr::null_mut());
        let saved = SAVED_STDOUT_FD.swap(-1, Ordering::SeqCst);
        if saved >= 0 {
            libc::dup2(saved, 1);
            libc::close(saved);
        }
    }
    let _ = std::io::stdout().flush();
}

#[derive(Parser, Debug)]
#[command(name = "local-ocr-engine", version, about = "ocr-rs PP-OCRv6 engine")]
struct Args {
    /// Image path
    image: PathBuf,

    /// Model directory (det/rec/keys). Default: $LOCAL_OCR_MODELS or ~/.cache/ocr-rs/models
    #[arg(short, long, env = "LOCAL_OCR_MODELS")]
    models_dir: Option<PathBuf>,

    /// PP-OCRv6 tier
    #[arg(long, default_value = "tiny")]
    tier: String,

    #[arg(short, long, value_enum, default_value_t = OutputFormat::Json)]
    format: OutputFormat,

    #[arg(long)]
    robust: bool,

    #[arg(long, default_value_t = 0.5)]
    min_confidence: f32,

    #[arg(short, long, default_value_t = 4)]
    threads: i32,
}

#[derive(Clone, Copy, Debug, ValueEnum)]
enum OutputFormat {
    Text,
    Json,
}

#[derive(Serialize)]
struct LineOut {
    text: String,
    confidence: f32,
    left: i32,
    top: i32,
    width: u32,
    height: u32,
}

fn default_models_dir() -> PathBuf {
    dirs::cache_dir()
        .unwrap_or_else(|| PathBuf::from("."))
        .join("ocr-rs")
        .join("models")
}

fn fail(format: OutputFormat, error: &str, hint: Option<&str>) -> ! {
    unmute_stdout();
    match format {
        OutputFormat::Json => {
            let mut v = serde_json::json!({ "ok": false, "error": error });
            if let Some(h) = hint {
                v["hint"] = serde_json::Value::String(h.to_string());
            }
            println!("{v}");
        }
        OutputFormat::Text => {
            eprint!("error: {error}");
            if let Some(h) = hint {
                eprint!(" ({h})");
            }
            eprintln!();
        }
    }
    std::process::exit(1);
}

fn main() -> Result<()> {
    let args = Args::parse();
    let format = args.format;

    if !matches!(args.tier.as_str(), "tiny" | "small" | "medium") {
        fail(
            format,
            "invalid_tier",
            Some("--tier 只能是 tiny / small / medium"),
        );
    }

    let image_path = if args.image.is_absolute() {
        args.image.clone()
    } else {
        std::env::current_dir()?.join(&args.image)
    };
    if !image_path.exists() {
        fail(
            format,
            "image_not_found",
            Some(&image_path.display().to_string()),
        );
    }

    let models_dir = args.models_dir.unwrap_or_else(default_models_dir);
    let det = models_dir.join(format!("PP-OCRv6_{}_det.mnn", args.tier));
    let rec = models_dir.join(format!("PP-OCRv6_{}_rec.mnn", args.tier));
    let keys = models_dir.join(format!("ppocr_keys_v6_{}.txt", args.tier));
    for path in [&det, &rec, &keys] {
        if !path.exists() {
            fail(
                format,
                "model_missing",
                Some(&format!("scripts/download-models.sh {}", args.tier)),
            );
        }
    }

    let config = OcrEngineConfig::new()
        .with_threads(args.threads)
        .with_min_result_confidence(args.min_confidence);

    let image = match image::open(&image_path) {
        Ok(image) => image,
        Err(e) => fail(format, "infer_failed", Some(&e.to_string())),
    };

    let options = if args.robust {
        RecognizeOptions::new().with_rotated_text_mode(RotatedTextMode::Robust)
    } else {
        RecognizeOptions::default()
    };

    mute_stdout();
    let load_started = Instant::now();
    let engine = match OcrEngine::new(&det, &rec, &keys, Some(config)) {
        Ok(engine) => engine,
        Err(e) => fail(format, "infer_failed", Some(&e.to_string())),
    };
    let load_elapsed = load_started.elapsed();

    let infer_started = Instant::now();
    let results = match engine.recognize_with_options(&image, &options) {
        Ok(results) => results,
        Err(e) => fail(format, "infer_failed", Some(&e.to_string())),
    };
    let infer_elapsed = infer_started.elapsed();
    drop(engine);
    unmute_stdout();

    let lines: Vec<LineOut> = results
        .into_iter()
        .map(|item| LineOut {
            text: item.text,
            confidence: item.confidence,
            left: item.bbox.rect.left(),
            top: item.bbox.rect.top(),
            width: item.bbox.rect.width(),
            height: item.bbox.rect.height(),
        })
        .collect();
    let text = lines
        .iter()
        .map(|l| l.text.as_str())
        .collect::<Vec<_>>()
        .join("\n");

    match format {
        OutputFormat::Json => {
            let payload = serde_json::json!({
                "ok": true,
                "engine": "ocr-rs",
                "tier": args.tier,
                "image": image_path.display().to_string(),
                "width": image.width(),
                "height": image.height(),
                "load_ms": load_elapsed.as_millis(),
                "infer_ms": infer_elapsed.as_millis(),
                "text": text,
                "lines": lines,
            });
            println!("{}", serde_json::to_string(&payload)?);
        }
        OutputFormat::Text => {
            if text.is_empty() {
                println!("(未识别到文本)");
            } else {
                println!("{text}");
            }
        }
    }

    Ok(())
}
