package orz_mania

// Mixer positions advance in audio blocks. Interpolate with the monotonic clock
// and gently follow the audio reference, rather than resetting on every block.
class AudioTimeline {
    var position: Float64=0.0
    var stamp: UInt64=0
    var initialized=false
    func reset(ms: Int64,now: UInt64): Unit { position=Float64(max(0,ms)); stamp=now; initialized=true }
    func sample(audio: Int64,now: UInt64): Int64 {
        if (!initialized) { reset(audio,now); return Int64(position) }
        let elapsed=Float64(now-stamp)/1000000.0
        stamp=now
        let predicted=position+elapsed
        // A long render stall must catch up to the audio, never replay stale frames.
        if (elapsed > 250.0 || Float64(audio)-predicted > 100.0) {
            position=max(position,Float64(audio))
        } else {
            let error=Float64(audio)-predicted
            let correction=max(-elapsed*0.02,min(elapsed*0.02,error*elapsed/250.0))
            // Bound extrapolation if the audio device stops making progress.
            position=max(position,min(predicted+correction,Float64(audio)+50.0))
        }
        Int64(position)
    }
}
