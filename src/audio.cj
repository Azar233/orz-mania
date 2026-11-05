package orz_mania

foreign {
    func SDL_CreateProperties(): UInt32
    func SDL_SetNumberProperty(props: UInt32,name: CString,value: Int64): Bool
    func SDL_DestroyProperties(props: UInt32): Unit
    func MIX_GetAudioDuration(audio: CPointer<Unit>): Int64
    func MIX_AudioFramesToMS(audio: CPointer<Unit>,frames: Int64): Int64
    func MIX_Init(): Bool
    func MIX_Quit(): Unit
    func MIX_CreateMixerDevice(id: UInt32, spec: CPointer<Unit>): CPointer<Unit>
    func MIX_DestroyMixer(mixer: CPointer<Unit>): Unit
    func MIX_LoadAudio(mixer: CPointer<Unit>, path: CString, predecode: Bool): CPointer<Unit>
    func MIX_DestroyAudio(audio: CPointer<Unit>): Unit
    func MIX_CreateTrack(mixer: CPointer<Unit>): CPointer<Unit>
    func MIX_SetTrackAudio(track: CPointer<Unit>, audio: CPointer<Unit>): Bool
    func MIX_PlayTrack(track: CPointer<Unit>, options: UInt32): Bool
    func MIX_StopTrack(track: CPointer<Unit>, fade: Int64): Bool
    func MIX_PauseTrack(track: CPointer<Unit>): Bool
    func MIX_ResumeTrack(track: CPointer<Unit>): Bool
    func MIX_SetTrackPlaybackPosition(track: CPointer<Unit>,frames: Int64): Bool
    func MIX_TrackMSToFrames(track: CPointer<Unit>,ms: Int64): Int64
    func MIX_GetTrackPlaybackPosition(track: CPointer<Unit>): Int64
    func MIX_TrackFramesToMS(track: CPointer<Unit>, frames: Int64): Int64
    func MIX_SetTrackFrequencyRatio(track: CPointer<Unit>,ratio: Float32): Bool
    func MIX_SetTrackGain(track: CPointer<Unit>, gain: Float32): Bool
    func MIX_TrackPlaying(track: CPointer<Unit>): Bool
}
class Music <: Resource {
    var mixer=CPointer<Unit>()
    var audio=CPointer<Unit>()
    var track=CPointer<Unit>()
    var initialized=false
    var closed=false
    var started=false
    var volume: Float32=0.65
    var previewJob: ?Future<CPointer<Unit>>=None
    var previewPath=""
    var previewLoads: Int64=0
    func discardPreview(wait!: Bool=false): Unit {
        if (let Some(job) <- previewJob) {
            let result=if (wait) { Some(job.get()) } else { job.tryGet() }
            if (let Some(loaded) <- result) {
                if (loaded.isNotNull()) { unsafe { MIX_DestroyAudio(loaded) } }
                previewJob=None; previewPath=""
            }
        }
    }
    func preparePreview(path: String): Bool {
        if (let Some(job) <- previewJob) {
            if (let Some(loaded) <- job.tryGet()) {
                let current=previewPath == path
                previewJob=None; previewPath=""
                if (current) {
                    require(loaded.isNotNull(),"Cannot decode audio: "+path)
                    stop()
                    if (audio.isNotNull()) { unsafe { MIX_DestroyAudio(audio) } }
                    audio=loaded
                    require(unsafe { MIX_SetTrackAudio(track,audio) },"Cannot attach audio")
                    let _=unsafe { MIX_SetTrackGain(track,volume) }
                    setRate(100)
                    return true
                }
                if (loaded.isNotNull()) { unsafe { MIX_DestroyAudio(loaded) } }
            }
        }
        if (previewJob.isNone()) {
            previewPath=path; previewLoads++
            let owner=mixer
            previewJob=Some(spawn {=>
                var loaded=CPointer<Unit>()
                try {
                    let c=unsafe { LibC.mallocCString(path) }
                    try (name=c.asResource()) { loaded=unsafe { MIX_LoadAudio(owner,name.value,false) } }
                } catch (_: Exception) { () }
                loaded
            })
        }
        false
    }
    init() {
        try {
        require(unsafe { MIX_Init() }, "SDL_mixer initialization failed"); initialized=true
        mixer=unsafe { MIX_CreateMixerDevice(UInt32(0xffffffff),CPointer<Unit>()) }
        require(mixer.isNotNull(), "Audio device unavailable")
        track=unsafe { MIX_CreateTrack(mixer) }
        require(track.isNotNull(), "Audio track unavailable")
        } catch (ex: Exception) { close(); throw ex }
    }
    // Cache the encoded source; decode during playback instead of retaining full-song PCM.
    func open(path: String,predecode!: Bool=false): Unit {
        discardPreview(wait: true)
        stop()
        if (audio.isNotNull()) { unsafe { MIX_DestroyAudio(audio) }; audio=CPointer<Unit>() }
        let c=unsafe { LibC.mallocCString(path) }
        try (name=c.asResource()) { audio=unsafe { MIX_LoadAudio(mixer,name.value,predecode) } }
        require(audio.isNotNull(),"Cannot decode audio: " + path)
        require(unsafe { MIX_SetTrackAudio(track,audio) }, "Cannot attach audio")
        let _=unsafe { MIX_SetTrackGain(track,volume) }; setRate(100)
    }
    func play(loop!: Bool=false): Unit {
        let props=if (loop) { unsafe { SDL_CreateProperties() } } else { UInt32(0) }
        try {
            if (loop) {
                require(props != 0,"Cannot create playback options")
                let c=unsafe { LibC.mallocCString("SDL_mixer.play.loops") }
                try (name=c.asResource()) { require(unsafe { SDL_SetNumberProperty(props,name.value,-1) },"Cannot enable looping") }
            }
            require(unsafe { MIX_PlayTrack(track,props) },"Cannot play audio"); started=true
        } finally { if (props != 0) { unsafe { SDL_DestroyProperties(props) } } }
    }
    func duration(): Int64 { unsafe { MIX_AudioFramesToMS(audio,MIX_GetAudioDuration(audio)) } }
    func seek(ms: Int64): Unit {
        let frames=unsafe { MIX_TrackMSToFrames(track,max(0,ms)) }
        require(frames >= 0 && unsafe { MIX_SetTrackPlaybackPosition(track,frames) },"Audio seek failed")
    }
    func stop(): Unit { if (track.isNotNull()) { let _=unsafe { MIX_StopTrack(track,0) } }; started=false }
    func pause(): Unit { let _=unsafe { MIX_PauseTrack(track) } }
    func resume(): Unit { let _=unsafe { MIX_ResumeTrack(track) } }
    func setVolume(value: Float32): Unit {
        volume=max(Float32(0.0),min(Float32(1.0),value))
        let _=unsafe { MIX_SetTrackGain(track,volume) }
    }
    func setRate(rate: Int64): Unit { require(rate >= 50 && rate <= 200 && unsafe { MIX_SetTrackFrequencyRatio(track,Float32(rate)/100.0) },"Cannot set playback rate") }
    func position(): Int64 { unsafe { MIX_TrackFramesToMS(track,MIX_GetTrackPlaybackPosition(track)) } }
    func playing(): Bool { unsafe { MIX_TrackPlaying(track) } }
    public func isClosed(): Bool { closed }
    public func close(): Unit {
        if (closed) { return }
        discardPreview(wait: true)
        if (mixer.isNotNull()) { unsafe { MIX_DestroyMixer(mixer) } }
        if (audio.isNotNull()) { unsafe { MIX_DestroyAudio(audio) } }
        if (initialized) { unsafe { MIX_Quit() } }
        closed=true
    }
}

