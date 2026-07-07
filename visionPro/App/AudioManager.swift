import AVFoundation

@MainActor
class AudioManager {
    static let shared = AudioManager()
    
    private var soundTrackPlayer: AVAudioPlayer?
    private var sfxPlayer: AVAudioPlayer?
    
    private init() {
        configureAudioSession()
    }
    
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
    func playSoundTrack() {
        guard soundTrackPlayer == nil else { return }
        
        guard let url = Bundle.main.url(forResource: "Sound Track", withExtension: "mp3") else {
            print("Sound Track.mp3 not found in bundle")
            return
        }
        
        do {
            soundTrackPlayer = try AVAudioPlayer(contentsOf: url)
            soundTrackPlayer?.numberOfLoops = -1
            soundTrackPlayer?.volume = 0.5
            soundTrackPlayer?.play()
        } catch {
            print("Failed to play Sound Track: \(error)")
        }
    }
    
    func stopSoundTrack() {
        soundTrackPlayer?.stop()
        soundTrackPlayer = nil
    }
    
    func playClosePortal() {
        guard let url = Bundle.main.url(forResource: "Close Portal", withExtension: "wav") else { return }
        do {
            sfxPlayer = try AVAudioPlayer(contentsOf: url)
            sfxPlayer?.play()
        } catch { }
    }
}
