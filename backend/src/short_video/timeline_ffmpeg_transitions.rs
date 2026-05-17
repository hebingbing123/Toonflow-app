//! FFmpeg xfade / fade_black filter graph builder (**NLE M2**).

use std::path::{Path, PathBuf};

use crate::short_video::timeline::{TimelineTransition, TimelineTransitionType, MAX_CROSSFADE_MS};
use crate::short_video::timeline_ffmpeg::FfmpegSegmentInput;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TransitionGraphPlan {
    pub filter_complex: String,
    pub video_out_label: String,
    pub reencode: bool,
}

/// Build filter_complex for chained transitions between trimmed segments.
#[must_use]
pub fn build_transition_filter_graph(
    segments: &[FfmpegSegmentInput],
    transitions: &[TimelineTransition],
) -> Option<TransitionGraphPlan> {
    if segments.len() < 2 {
        return None;
    }
    let needs_xfade = transitions.iter().any(|t| {
        matches!(
            t.transition_type,
            TimelineTransitionType::Crossfade | TimelineTransitionType::FadeBlack
        )
    });
    if !needs_xfade {
        return None;
    }

    let mut filter_parts = Vec::new();
    let mut offsets = Vec::new();
    let mut cursor_secs = 0.0_f64;
    for (i, seg) in segments.iter().enumerate() {
        let dur = ((seg.out_ms - seg.in_ms).max(1) as f64) / 1000.0;
        if i + 1 < segments.len() {
            let tr = transitions.get(i).cloned().unwrap_or(TimelineTransition {
                transition_type: TimelineTransitionType::Cut,
                duration_ms: 0,
            });
            let xdur = match tr.transition_type {
                TimelineTransitionType::Cut => 0.0,
                TimelineTransitionType::Crossfade | TimelineTransitionType::FadeBlack => {
                    (tr.duration_ms.clamp(1, MAX_CROSSFADE_MS) as f64) / 1000.0
                }
            };
            let offset = (cursor_secs + dur - xdur).max(0.0);
            offsets.push((xdur, offset, tr.transition_type));
            cursor_secs = offset + xdur;
        } else {
            cursor_secs += dur;
        }
    }

    for (i, _) in segments.iter().enumerate() {
        filter_parts.push(format!("[{i}:v]setpts=PTS-STARTPTS[v{i}];"));
    }

    let mut last_v = "v0".to_string();
    for (i, (xdur, offset, kind)) in offsets.iter().enumerate() {
        let next_v = format!("v{}", i + 1);
        let out_label = format!("x{i}");
        let transition_name = match kind {
            TimelineTransitionType::Crossfade => "fade",
            TimelineTransitionType::FadeBlack => "fadeblack",
            TimelineTransitionType::Cut => continue,
        };
        filter_parts.push(format!(
            "[{last_v}][{next_v}]xfade=transition={transition_name}:duration={xdur:.3}:offset={offset:.3}[{out_label}];",
            last_v = last_v,
            next_v = next_v,
            transition_name = transition_name,
            xdur = xdur,
            offset = offset,
            out_label = out_label,
        ));
        last_v = out_label;
    }

    let video_out = last_v;
    Some(TransitionGraphPlan {
        filter_complex: filter_parts.join(""),
        video_out_label: video_out,
        reencode: true,
    })
}

#[must_use]
pub fn xfade_mux_args(
    segment_paths: &[PathBuf],
    plan: &TransitionGraphPlan,
    output: &Path,
) -> Vec<String> {
    let mut args = vec!["-y".to_string()];
    for p in segment_paths {
        args.push("-i".to_string());
        args.push(p.display().to_string());
    }
    args.push("-filter_complex".to_string());
    args.push(plan.filter_complex.clone());
    args.push("-map".to_string());
    args.push(format!("[{}]", plan.video_out_label));
    args.push("-map".to_string());
    args.push("0:a?".to_string());
    args.push("-c:v".to_string());
    args.push("libx264".to_string());
    args.push("-preset".to_string());
    args.push("veryfast".to_string());
    args.push("-c:a".to_string());
    args.push("aac".to_string());
    args.push(output.display().to_string());
    args
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    #[test]
    fn crossfade_graph_has_xfade() {
        let segs = vec![
            FfmpegSegmentInput {
                path: PathBuf::from("/a.mp4"),
                in_ms: 0,
                out_ms: 3000,
                effect_preset_id: None,
            },
            FfmpegSegmentInput {
                path: PathBuf::from("/b.mp4"),
                in_ms: 0,
                out_ms: 3000,
                effect_preset_id: None,
            },
        ];
        let transitions = vec![TimelineTransition {
            transition_type: TimelineTransitionType::Crossfade,
            duration_ms: 500,
        }];
        let plan = build_transition_filter_graph(&segs, &transitions).expect("plan");
        assert!(plan.filter_complex.contains("xfade"));
        assert!(plan.filter_complex.contains("fade"));
        assert!(plan.reencode);
    }

    #[test]
    fn cut_only_returns_none() {
        let segs = vec![
            FfmpegSegmentInput {
                path: PathBuf::from("/a.mp4"),
                in_ms: 0,
                out_ms: 2000,
                effect_preset_id: None,
            },
            FfmpegSegmentInput {
                path: PathBuf::from("/b.mp4"),
                in_ms: 0,
                out_ms: 2000,
                effect_preset_id: None,
            },
        ];
        let transitions = vec![TimelineTransition {
            transition_type: TimelineTransitionType::Cut,
            duration_ms: 0,
        }];
        assert!(build_transition_filter_graph(&segs, &transitions).is_none());
    }
}
