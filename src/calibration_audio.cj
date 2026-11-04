package orz_mania

import sdl.system.PerformanceClock
import std.math.{sin,exp}

let CALIBRATION_PERIOD: Int64=750 // 80 BPM, unambiguous inside the +/-300ms adjustment range.
let CALIBRATION_LOOP: Int64=12000
foreign {
    func SDL_IOFromConstMem(data: CPointer<Unit>,length: UIntNative): CPointer<Unit>
    func MIX_LoadAudio_IO(mixer: CPointer<Unit>,io: CPointer<Unit>,predecode: Bool,closeio: Bool): CPointer<Unit>
    func MIX_DestroyTrack(track: CPointer<Unit>): Unit
    func memcpy(to: CPointer<Unit>,from: CPointer<Unit>,length: UIntNative): CPointer<Unit>
}
func calibrationWord(bytes: Array<UInt8>,at: Int64,value: UInt32,count: Int64): Unit {
    var remaining=value
    for (i in 0..count) { bytes[at+i]=UInt8(remaining%256); remaining=remaining/256 }
}
// A short generated drum loop; no bundled song or external audio file is required.
func calibrationWave(): Array<UInt8> {
    let samples=CALIBRATION_LOOP*48
    let bytes=Array<UInt8>(44+samples*2,repeat: 0)
    for ((at,value) in [(0,"RIFF"),(8,"WAVE"),(12,"fmt "),(36,"data")]) {
        let word=value.toArray(); for (i in 0..4) { bytes[at+i]=word[i] }
    }
    calibrationWord(bytes,4,UInt32(bytes.size-8),4); calibrationWord(bytes,16,16,4)
    calibrationWord(bytes,20,1,2); calibrationWord(bytes,22,1,2)
    calibrationWord(bytes,24,48000,4); calibrationWord(bytes,28,96000,4)
    calibrationWord(bytes,32,2,2); calibrationWord(bytes,34,16,2)
    calibrationWord(bytes,40,UInt32(samples*2),4)
    for (beat in 0..CALIBRATION_LOOP/CALIBRATION_PERIOD) {
        for (i in 0..1920) {
            let time=Float64(i)/48000.0
            let wave=(1.0-exp(-time*1600.0))*(sin(time*6.283185307179586*125.0)*exp(-time*80.0)+0.25*sin(time*6.283185307179586*1500.0)*exp(-time*220.0))
            let value=Int64(wave*11000.0)
            let bits=UInt32(if (value < 0) { value+65536 } else { value })
            calibrationWord(bytes,44+(beat*CALIBRATION_PERIOD*48+i)*2,bits,2)
        }
    }
    bytes
}
class CalibrationAudio <: Resource {
    var track=CPointer<Unit>()
    var audio=CPointer<Unit>()
    var encoded=CPointer<UInt8>()
    var closed=false
    var lastRaw: Int64=0
    var loopBase: Int64=0
    let timeline=AudioTimeline()
    init(music: Music) {
        try {
            let wave=calibrationWave(); let size=UIntNative(wave.size)
            encoded=unsafe { LibC.malloc<UInt8>(count: wave.size) }
            require(encoded.isNotNull(),"Cannot allocate calibration audio")
            let pinned=unsafe { acquireArrayRawData(wave) }
            let _=unsafe { memcpy(CPointer<Unit>(encoded),CPointer<Unit>(pinned.pointer),size) }
            unsafe { releaseArrayRawData(pinned) }
            let stream=unsafe { SDL_IOFromConstMem(CPointer<Unit>(encoded),size) }
            require(stream.isNotNull(),"Cannot create calibration audio stream")
            audio=unsafe { MIX_LoadAudio_IO(music.mixer,stream,true,true) }
            require(audio.isNotNull(),"Cannot load calibration drum loop")
            track=unsafe { MIX_CreateTrack(music.mixer) }
            require(track.isNotNull() && unsafe { MIX_SetTrackAudio(track,audio) },"Cannot attach calibration track")
        } catch (ex: Exception) { close(); throw ex }
    }
    func start(sound: Bool): Unit {
        let props=unsafe { SDL_CreateProperties() }
        require(props != 0,"Cannot create calibration playback options")
        try {
            let c=unsafe { LibC.mallocCString("SDL_mixer.play.loops") }
            try (name=c.asResource()) { require(unsafe { SDL_SetNumberProperty(props,name.value,-1) },"Cannot loop calibration track") }
            setSound(sound)
            require(unsafe { MIX_PlayTrack(track,props) },"Cannot start calibration track")
            lastRaw=0; loopBase=0; timeline.reset(0,PerformanceClock.ticksNanoseconds())
        } finally { unsafe { SDL_DestroyProperties(props) } }
    }
    func setSound(enabled: Bool): Unit { require(unsafe { MIX_SetTrackGain(track,if (enabled) { Float32(0.5) } else { Float32(0.0) }) },"Cannot set calibration volume") }
    func stop(): Unit { if (track.isNotNull()) { let _=unsafe { MIX_StopTrack(track,0) } } }
    func position(): Int64 {
        let raw=unsafe { MIX_TrackFramesToMS(track,MIX_GetTrackPlaybackPosition(track)) }
        require(raw >= 0,"Calibration audio clock is unavailable")
        if (raw < lastRaw-CALIBRATION_LOOP/2) { loopBase+=CALIBRATION_LOOP }
        lastRaw=raw
        timeline.sample(loopBase+raw,PerformanceClock.ticksNanoseconds())
    }
    public func close(): Unit {
        if (closed) { return }
        if (track.isNotNull()) { unsafe { MIX_DestroyTrack(track) }; track=CPointer<Unit>() }
        if (audio.isNotNull()) { unsafe { MIX_DestroyAudio(audio) }; audio=CPointer<Unit>() }
        if (encoded.isNotNull()) { unsafe { LibC.free(encoded) }; encoded=CPointer<UInt8>() }
        closed=true
    }
    public func isClosed(): Bool { closed }
}
