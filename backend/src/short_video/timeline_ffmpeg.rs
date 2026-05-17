//! FFmpeg argv builder for timeline preview (**NLE M1–M3**, dry-run friendly).

use std::path::{Path, PathBuf};

use crate::short_video::timeline::TimelineVoiceoverClip;
use crate::short_video::timeline::{TimelineTransition, TimelineTransitionType};
use crate::short_video::timeline_effects::segment_trim_args_with_effect;
use crate::short_video::timeline_ffmpeg_transitions::{
    build_transition_filter_graph, xfade_mux_args,
};

/// One trimmed segment on disk before concat.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FfmpegSegmentInput {
    pub path: PathBuf,
    pub in_ms: i64,
    pub out_ms: i64,
    pub effect_preset_id: Option<String>,
}

#[derive(Debug, Clone, Default)]
pub struct PreviewAudioMixInput {
    pub bgm_path: Option<PathBuf>,
    pub bgm_volume: f64,
    pub voiceover_clips: Vec<TimelineVoiceoverClip>,
    pub voiceover_local_paths: Vec<PathBuf>,
    pub duck_bgm_during_voiceover: bool,
}

#[derive(Debug, Clone, Default)]
pub struct PreviewSubtitleInput {
    pub srt_path: Option<PathBuf>,
    pub font_size: u32,
    pub margin_v: u32,
}

#[must_use]
#[allow(dead_code)]
pub fn segment_trim_args(input: &Path, in_ms: i64, out_ms: i64, output: &Path) -> Vec<String> {
    let start = format!("{:.3}", in_ms as f64 / 1000.0);
    let duration = format!("{:.3}", (out_ms - in_ms).max(1) as f64 / 1000.0);
    vec![
        "-y".into(),
        "-ss".into(),
        start,
        "-i".into(),
        input.display().to_string(),
        "-t".into(),
        duration,
        "-c".into(),
        "copy".into(),
        output.display().to_string(),
    ]
}

#[must_use]
pub fn concat_demuxer_list_content(segment_paths: &[PathBuf]) -> String {
    segment_paths
        .iter()
        .map(|p| format!("file '{}'", p.display()))
        .collect::<Vec<_>>()
        .join("\n")
}

#[must_use]
pub fn concat_video_args(list_file: &Path, output: &Path) -> Vec<String> {
    vec![
        "-y".into(),
        "-f".into(),
        "concat".into(),
        "-safe".into(),
        "0".into(),
        "-i".into(),
        list_file.display().to_string(),
        "-c".into(),
        "copy".into(),
        output.display().to_string(),
    ]
}

/// Mix BGM at constant volume under the main video audio.
#[must_use]
pub fn mix_bgm_args(
    video_path: &Path,
    bgm_path: &Path,
    output: &Path,
    bgm_volume: f64,
) -> Vec<String> {
    let vol = bgm_volume.clamp(0.0, 1.0);
    let filter = format!(
        "[0:a]aformat=sample_rates=48000:channel_layouts=stereo[a0];\
         [1:a]volume={vol},aformat=sample_rates=48000:channel_layouts=stereo[a1];\
         [a0][a1]amix=inputs=2:duration=first:dropout_transition=0[aout]"
    );
    vec![
        "-y".into(),
        "-i".into(),
        video_path.display().to_string(),
        "-i".into(),
        bgm_path.display().to_string(),
        "-filter_complex".into(),
        filter,
        "-map".into(),
        "0:v:0".into(),
        "-map".into(),
        "[aout]".into(),
        "-c:v".into(),
        "copy".into(),
        "-c:a".into(),
        "aac".into(),
        "-shortest".into(),
        output.display().to_string(),
    ]
}

/// Burn SRT subtitles (path escaped for ffmpeg filter).
#[must_use]
pub fn burn_subtitles_args(
    video_path: &Path,
    srt_path: &Path,
    output: &Path,
    font_size: u32,
    margin_v: u32,
) -> Vec<String> {
    let escaped = escape_subtitles_path(srt_path);
    let force_style = format!("FontSize={font_size},MarginV={margin_v}");
    let vf = format!("subtitles={escaped}:force_style='{force_style}'");
    vec![
        "-y".into(),
        "-i".into(),
        video_path.display().to_string(),
        "-vf".into(),
        vf,
        "-c:a".into(),
        "copy".into(),
        output.display().to_string(),
    ]
}

fn escape_subtitles_path(path: &Path) -> String {
    path.display()
        .to_string()
        .replace('\\', "\\\\")
        .replace(':', "\\:")
        .replace('\'', "\\'")
}

/// Voiceover + optional BGM with simple ducking (BGM ×0.3 when any VO present).
#[must_use]
pub fn mix_voiceover_bgm_args(
    video_path: &Path,
    output: &Path,
    vo_paths: &[PathBuf],
    vo_clips: &[TimelineVoiceoverClip],
    bgm_path: Option<&Path>,
    bgm_volume: f64,
    duck_bgm: bool,
) -> Vec<String> {
    let mut args = vec![
        "-y".to_string(),
        "-i".to_string(),
        video_path.display().to_string(),
    ];
    let mut filter = String::from("[0:a]aformat=sample_rates=48000:channel_layouts=stereo[main];");
    let mut mix_inputs = vec!["[main]".to_string()];
    let mut idx = 1usize;

    for (path, clip) in vo_paths.iter().zip(vo_clips.iter()) {
        let delay = clip.start_ms.max(0);
        args.push("-i".to_string());
        args.push(path.display().to_string());
        filter.push_str(&format!(
            "[{idx}:a]adelay={delay}|{delay},volume={vol},aformat=sample_rates=48000:channel_layouts=stereo[vo{idx}];",
            idx = idx,
            delay = delay,
            vol = clip.volume.clamp(0.0, 2.0),
        ));
        mix_inputs.push(format!("[vo{idx}]"));
        idx += 1;
    }

    if let Some(bgm) = bgm_path {
        let effective_bgm = if duck_bgm && !vo_paths.is_empty() {
            bgm_volume * 0.3
        } else {
            bgm_volume
        };
        args.push("-i".to_string());
        args.push(bgm.display().to_string());
        filter.push_str(&format!(
            "[{idx}:a]volume={effective_bgm},aformat=sample_rates=48000:channel_layouts=stereo[bgm];",
            idx = idx,
            effective_bgm = effective_bgm.clamp(0.0, 1.0),
        ));
        mix_inputs.push("[bgm]".to_string());
    }

    let n = mix_inputs.len();
    filter.push_str(&format!(
        "{inputs}amix=inputs={n}:duration=first:dropout_transition=0[aout]",
        inputs = mix_inputs.join(""),
        n = n,
    ));

    args.push("-filter_complex".to_string());
    args.push(filter);
    args.push("-map".to_string());
    args.push("0:v:0".to_string());
    args.push("-map".to_string());
    args.push("[aout]".to_string());
    args.push("-c:v".to_string());
    args.push("copy".to_string());
    args.push("-c:a".to_string());
    args.push("aac".to_string());
    args.push("-shortest".to_string());
    args.push(output.display().to_string());
    args
}

#[must_use]
pub fn needs_xfade_pipeline(transitions: &[TimelineTransition]) -> bool {
    transitions.iter().any(|t| {
        matches!(
            t.transition_type,
            TimelineTransitionType::Crossfade | TimelineTransitionType::FadeBlack
        )
    })
}

#[allow(dead_code)]
#[must_use]
pub fn preview_pipeline_command_strings(
    segments: &[FfmpegSegmentInput],
    work_dir: &Path,
    output_mp4: &Path,
    bgm_path: Option<&Path>,
    bgm_volume: f64,
) -> Vec<Vec<String>> {
    preview_pipeline_command_strings_full(
        segments,
        work_dir,
        output_mp4,
        bgm_path,
        bgm_volume,
        &[],
        &PreviewSubtitleInput::default(),
        &PreviewAudioMixInput::default(),
    )
}

#[allow(clippy::too_many_arguments)]
#[must_use]
pub fn preview_pipeline_command_strings_full(
    segments: &[FfmpegSegmentInput],
    work_dir: &Path,
    output_mp4: &Path,
    bgm_path: Option<&Path>,
    bgm_volume: f64,
    transitions: &[TimelineTransition],
    subtitles: &PreviewSubtitleInput,
    audio: &PreviewAudioMixInput,
) -> Vec<Vec<String>> {
    let mut commands = Vec::new();
    let mut trimmed = Vec::new();
    for (idx, seg) in segments.iter().enumerate() {
        let out = work_dir.join(format!("seg_{idx}.mp4"));
        commands.push(segment_trim_args_with_effect(
            &seg.path,
            seg.in_ms,
            seg.out_ms,
            &out,
            seg.effect_preset_id.as_deref(),
        ));
        trimmed.push(out);
    }

    let concat_out = work_dir.join("concat.mp4");
    let xfade_plan = build_transition_filter_graph(segments, transitions);
    if let Some(plan) = xfade_plan {
        commands.push(xfade_mux_args(&trimmed, &plan, &concat_out));
    } else {
        let list_file = work_dir.join("concat.txt");
        commands.push(concat_video_args(&list_file, &concat_out));
    }

    let mut current = concat_out;

    if let Some(srt) = subtitles.srt_path.as_ref() {
        let sub_out = work_dir.join("sub_burn.mp4");
        commands.push(burn_subtitles_args(
            &current,
            srt,
            &sub_out,
            subtitles.font_size,
            subtitles.margin_v,
        ));
        current = sub_out;
    }

    let has_vo = !audio.voiceover_local_paths.is_empty();
    let has_bgm = bgm_path.is_some() || audio.bgm_path.is_some();
    if has_vo || has_bgm {
        let bgm = audio.bgm_path.as_deref().or(bgm_path);
        if has_vo {
            commands.push(mix_voiceover_bgm_args(
                &current,
                output_mp4,
                &audio.voiceover_local_paths,
                &audio.voiceover_clips,
                bgm,
                audio.bgm_volume.max(bgm_volume),
                audio.duck_bgm_during_voiceover,
            ));
        } else if let Some(bgm_p) = bgm {
            commands.push(mix_bgm_args(&current, bgm_p, output_mp4, bgm_volume));
        }
    } else {
        commands.push(vec![
            "-y".into(),
            "-i".into(),
            current.display().to_string(),
            "-c".into(),
            "copy".into(),
            output_mp4.display().to_string(),
        ]);
    }

    commands
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::short_video::timeline::TimelineTransition;
    use std::path::PathBuf;

    #[test]
    fn trim_args_use_ss_and_duration() {
        let args = segment_trim_args(Path::new("/in.mp4"), 1000, 4000, Path::new("/out.mp4"));
        assert!(args.contains(&"-ss".to_string()));
        assert!(args.contains(&"1.000".to_string()));
        assert!(args.contains(&"-t".to_string()));
        assert!(args.contains(&"3.000".to_string()));
    }

    #[test]
    fn concat_list_escapes_paths() {
        let list = concat_demuxer_list_content(&[PathBuf::from("/tmp/a.mp4")]);
        assert!(list.contains("file '/tmp/a.mp4'"));
    }

    #[test]
    fn preview_pipeline_includes_bgm_mix_when_present() {
        let segs = vec![FfmpegSegmentInput {
            path: PathBuf::from("/in.mp4"),
            in_ms: 0,
            out_ms: 2000,
            effect_preset_id: None,
        }];
        let cmds = preview_pipeline_command_strings(
            &segs,
            Path::new("/work"),
            Path::new("/out.mp4"),
            Some(Path::new("/bgm.mp3")),
            0.4,
        );
        assert!(cmds.iter().flatten().any(|a| a.contains("amix")));
    }

    #[test]
    fn crossfade_pipeline_uses_xfade_not_concat_demuxer() {
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
        let cmds = preview_pipeline_command_strings_full(
            &segs,
            Path::new("/work"),
            Path::new("/out.mp4"),
            None,
            0.35,
            &transitions,
            &PreviewSubtitleInput::default(),
            &PreviewAudioMixInput::default(),
        );
        assert!(cmds.iter().flatten().any(|a| a.contains("xfade")));
    }
}
