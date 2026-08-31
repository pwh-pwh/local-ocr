use std::path::PathBuf;
use std::time::Instant;

use anyhow::Result;
use clap::{Parser, ValueEnum};
use ocr_rs::{OcrEngine, OcrEngineConfig, RecognizeOptions, RotatedTextMode};
use serde::Serialize;

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
                Some("bash scripts/download-models.sh"),
            );
        }
    }

    let config = OcrEngineConfig::new()
        .with_threads(args.threads)
        .with_min_result_confidence(args.min_confidence);

    let load_started = Instant::now();
    let engine = match OcrEngine::new(&det, &rec, &keys, Some(config)) {
        Ok(engine) => engine,
        Err(e) => fail(format, "infer_failed", Some(&e.to_string())),
    };
    let load_elapsed = load_started.elapsed();

    let image = match image::open(&image_path) {
        Ok(image) => image,
        Err(e) => fail(format, "infer_failed", Some(&e.to_string())),
    };

    let options = if args.robust {
        RecognizeOptions::new().with_rotated_text_mode(RotatedTextMode::Robust)
    } else {
        RecognizeOptions::default()
    };

    let infer_started = Instant::now();
    let results = match engine.recognize_with_options(&image, &options) {
        Ok(results) => results,
        Err(e) => fail(format, "infer_failed", Some(&e.to_string())),
    };
    let infer_elapsed = infer_started.elapsed();

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
