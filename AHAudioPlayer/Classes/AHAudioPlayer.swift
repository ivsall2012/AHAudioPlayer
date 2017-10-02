//
//  AHAudioPlayer.swift
//  AHAudioPlayer
//
//  Created by Andy Tong on 6/24/17.
//  Copyright © 2017 Andy Tong. All rights reserved.
//

import UIKit
import AVFoundation
import MediaPlayer

fileprivate var playerContext = "AHAudioPlayerContext"
fileprivate var playerRateContext = "playerRateContext"


fileprivate struct AHPlayerKeyPath {
    static let status = #keyPath(AVPlayerItem.status)
    static let keepUp = #keyPath(AVPlayerItem.isPlaybackLikelyToKeepUp)
    static let bufferFull = #keyPath(AVPlayerItem.isPlaybackBufferFull)
    static let bufferEmpty = #keyPath(AVPlayerItem.isPlaybackBufferEmpty)
}



public let AHAudioPlayerDidStartToPlay = Notification.Name("AHAudioPlayerDidStartToPlay")

/// Sent by audioPlayer, when audioPlayer's state changes
public let AHAudioPlayerDidChangeState = Notification.Name("AHAudioPlayerDidChangeState")


public let AHAudioPlayerDidSwitchPlay = Notification.Name("AHAudioPlayerDidSwitchPlay")

/// Sent by audioPlayer, not the manager!, when an audio reach its end
public let AHAudioPlayerDidReachEnd = Notification.Name("AHAudioPlayerDidReachEnd")

public let AHAudioPlayerFailedToReachEnd = Notification.Name("AHAudioPlayerFailedToReachEnd")

public enum AHAudioPlayerState {
    case none
    case loading
    case playing
    case stopped
    case paused
}

public enum AHAudioRateSpeed: Float {
    case one = 1.0
    case one_two_five = 1.25
    case one_five = 1.5
    case one_seven_five = 1.75
    case two = 2.0
}

public protocol AHAudioPlayerDelegate: class {
    func audioPlayerDidStartToPlay(_ player: AHAudioPlayer)
    func audioPlayerDidReachEnd(_ player: AHAudioPlayer)
    
    /// AHAudioPlayerDidSwitchPlay can act as 'willStartToPlay'
    func audioPlayerDidSwitchPlay(_ player: AHAudioPlayer)
    func audioPlayerDidChangeState(_ player: AHAudioPlayer)
    func audioPlayerFailedToReachEnd(_ player: AHAudioPlayer)
    // The player doesn't what to play next or previous, the delegate should play next track in usual way
    func audioPlayerShouldPlayNext(_ player: AHAudioPlayer) -> Bool
    func audioPlayerShouldPlayPrevious(_ player: AHAudioPlayer) -> Bool
    func audioPlayerShouldChangePlaybackRate(_ player: AHAudioPlayer) -> Bool
    func audioPlayerShouldSeekForward(_ player: AHAudioPlayer) -> Bool
    func audioPlayerShouldSeekBackward(_ player: AHAudioPlayer) -> Bool
    
    func audioPlayerGetTrackTitle(_ player: AHAudioPlayer) -> String?
    func audioPlayerGetAlbumTitle(_ player: AHAudioPlayer) -> String?
    func audioPlayerGetAlbumCover(_ player: AHAudioPlayer, _ callback: @escaping (_ coverImage: UIImage?)->Void)
}
extension AHAudioPlayerDelegate {
    public func audioPlayerWillStartToPlay(_ player: AHAudioPlayer){}
    public func audioPlayerDidStartToPlay(_ player: AHAudioPlayer){}
    public func audioPlayerDidReachEnd(_ player: AHAudioPlayer){}
    public func audioPlayerDidSwitchPlay(_ player: AHAudioPlayer){}
    public func audioPlayerDidChangeState(_ player: AHAudioPlayer){}
    public func audioPlayerFailedToReachEnd(_ player: AHAudioPlayer){}

    public func audioPlayerShouldPlayNext(_ player: AHAudioPlayer) -> Bool{
        return false
    }
    public func audioPlayerShouldPlayPrevious(_ player: AHAudioPlayer) -> Bool{
        return false
    }
    public func audioPlayerShouldChangePlaybackRate(_ player: AHAudioPlayer) -> Bool{
        return false
    }
    public func audioPlayerShouldSeekForward(_ player: AHAudioPlayer) -> Bool {
        return false
    }
    public func audioPlayerShouldSeekBackward(_ player: AHAudioPlayer) -> Bool{
        return false
    }
    public func audioPlayerGetTractTitle(_ player: AHAudioPlayer) -> String?{return nil}
    public func audioPlayerGetAlbumTitle(_ player: AHAudioPlayer) -> String?{return nil}
    public func audioPlayerGetAlbumCover(_ player: AHAudioPlayer, _ callback: @escaping (_ coverImage: UIImage?)->Void) {callback(nil)}
}


public final class AHAudioPlayer: NSObject {
    public static let shared = AHAudioPlayer()
    public weak var delegate: AHAudioPlayerDelegate?
    
    
    public override init() {
        super.init()
        setupRemoteControl()
    }

    
    fileprivate var notificaitonHandlers = [NSObjectProtocol]()
    // setup
    fileprivate var isSessionSetup = false
    // if it's true, when stalled then canKeepUp, player won't play automatically since the user already manually pause it for buffering
    fileprivate var isManuallyPaused: Bool = false
    fileprivate var isPausedBeforeEnterBackground = false
    /// Is requested to seek to a progress and then play, instead of playing from the begining
    fileprivate var isSeekToPlayMode = false
    fileprivate var seekToTime: TimeInterval = 0.0
    
    fileprivate var asset: AVURLAsset?
    fileprivate var playerItem: AVPlayerItem?
    fileprivate var player: AVPlayer?
    fileprivate(set) var state: AHAudioPlayerState = .none {
        didSet {
            self.delegate?.audioPlayerDidChangeState(self)
            NotificationCenter.default.post(name: AHAudioPlayerDidChangeState, object: nil)
        }
    }
    
    fileprivate func updateNowPlaying() {
        // Define Now Playing Info
        var nowPlayingInfo = [String : Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = self.delegate?.audioPlayerGetTrackTitle(self)
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = self.delegate?.audioPlayerGetAlbumTitle(self)
        let url = self.asset?.url
        self.delegate?.audioPlayerGetAlbumCover(self, { (image) in
            let url = url
            let thisUrl = self.asset?.url
            guard url == thisUrl else {
                return
            }
            if let image = image {
                if #available(iOS 10.0, *) {
                    MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyArtwork] =
                        MPMediaItemArtwork(boundsSize: image.size) { size in
                            return image
                    }
                } else {
                    MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(image: image)
                }
            }
        })
        
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = Double(self.currentTime)
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = Double(self.duration)
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = Double(self.rate)
        // Set the metadata
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    
    /// plackback progress in percentage
    public var progress: Double {
        get {
            guard duration > 0.0 && currentTime > 0.0 else {
                return 0.0
            }
            return currentTime / duration
        }
    }
    
    /// loaded progress in percentage
    public var loadedProgress: Double {
        get {
            guard duration > 0.0 else {
                return 0.0
            }
            
            guard let timeRange = playerItem?.loadedTimeRanges.last as? CMTimeRange else{
                return 0.0
            }
            
            let loadedTime = CMTimeAdd(timeRange.start, timeRange.duration)
            let loadedTimeSec = CMTimeGetSeconds(loadedTime)
            let progress = loadedTimeSec / duration
            return progress
        }
    }
    
    // In seconds
    public var duration: TimeInterval {
        get {
            guard let playerItem = self.playerItem else {
                return 0.0
            }
            let durationCM = playerItem.duration
            let durationSec = CMTimeGetSeconds(durationCM)
            
            return durationSec
        }
    }
    
    public var durationPretty: String {
        get {
            guard duration.isFinite else {
                return ""
            }
            guard duration > 0.0 else {
                return ""
            }
            let hours = Int(duration.rounded()) / 3600
            if hours == 0 {
                let minutes = Int(duration.rounded()) / 60
                let seconds = Int(duration.rounded()) % 60
                return String(format: "%02ld:%02ld", minutes,seconds)
            }else{
                let minutesLeft = Int(duration.rounded()) - hours * 3600
                let minutes = minutesLeft / 60
                let seconds = minutesLeft % 60
                return String(format: "%02ld:%02ld:%02ld", hours,minutes,seconds)
            }
        }
    }
    
    
    /// In seconds
    public var currentTime: TimeInterval {
        get {
            guard let playerItem = self.playerItem else {
                return 0.0
            }
            let currentCM = playerItem.currentTime()
            let currentSec = CMTimeGetSeconds(currentCM)
            
            return currentSec
        }
    }
    
    public var currentTimePretty: String {
        get {
            guard currentTime.isFinite else {
                return ""
            }
            guard currentTime > 0.0 else {
                return ""
            }
            let minutes = Int(currentTime.rounded()) / 60
            let seconds = Int(currentTime.rounded()) % 60
            return String(format: "%02ld:%02ld", minutes,seconds)
        }
    }
    
    public var rate: Float {
        set {
            guard let player = self.player else {
                return
            }
            // 0.0 is for pausing, not doing here
            guard newValue > 0.0 && newValue <= 2.0 else {
                return
            }
            
            player.rate = newValue
            
        }
        
        get {
            guard let player = self.player else {
                return 0.0
            }
            return player.rate
        }
    }
    
    public var muted: Bool {
        set {
            guard let player = self.player else {
                return
            }
            player.isMuted = newValue
        }
        
        get {
            return player?.isMuted ?? false
        }
    }
    
    public var volumn: Float {
        set {
            guard let player = self.player else {
                return
            }
            guard newValue >= 0.0 && newValue <= 1.0 else {
                return
            }
            player.volume = newValue
            
            if newValue > 0.0 {
                self.muted = false
            }
            
        }
        
        get {
            return player?.volume ?? 0.0
        }
    }
    
    
}

//MARK:- Public APIs
extension AHAudioPlayer {
    public func play(url: URL, toTime: TimeInterval? = nil){
        guard state == .none || state == .stopped else {
            print("You have to stop the playing first!!")
            return
        }
        
        if let toTime = toTime, toTime > 0.0{
            self.isSeekToPlayMode = true
            self.seekToTime = toTime
        }else{
            self.isSeekToPlayMode = false
            self.seekToTime = 0.0
        }
        
        // 1. AVURLAsset
        asset = AVURLAsset(url: url)
        
//#### NOTE: if you get an exception about libc++abi.dylib,
/* Add your exception breakpoint and edit the exception type from "All" to "Objective-C exceptions"
 
 Some classes in AudioToolbox throw regular C++ exceptions. You can filter them off this way.
         https://stackoverflow.com/questions/9683547/avaudioplayer-throws-breakpoint-in-debug-mode
*/
        
        // 2. AVPlayerItem
        playerItem = AVPlayerItem(asset: asset!)
        // 3. AVPlayer
        player = AVPlayer(playerItem: playerItem!)
        player?.actionAtItemEnd = .pause
        if #available(iOS 10.0, *) {
            // play whenever there's enough buffer, has higher risk of stalling though
            player?.automaticallyWaitsToMinimizeStalling = false
        }
        
        state = .loading
        setup()
        self.delegate?.audioPlayerDidSwitchPlay(self)
        NotificationCenter.default.post(name: AHAudioPlayerDidSwitchPlay, object: nil)
    }
    
    public func resume() {
        guard let player = player else {
            return
        }
        guard state == .paused || state == .loading else {
            return
        }
        
        guard isPausedBeforeEnterBackground == false else {
            return
        }
        
        player.play()
        state = .playing
        self.updateNowPlaying()
        // reset isManuallyPaused
        isManuallyPaused = false
        self.delegate?.audioPlayerDidStartToPlay(self)
        NotificationCenter.default.post(name: AHAudioPlayerDidStartToPlay, object: nil)
    }
    
    public func pause() {
        guard let player = player else {
            return
        }
        
        guard state == .playing else {
            return
        }
        // Have to change state firt!! otherwise the 'rate' KVO will disturb the whole stateDidChange notification flow.
        state = .paused
        
        player.pause()
        isManuallyPaused = true
    }
    
    public func stop() {
        guard state != .stopped else {
            return
        }
        removeListeners()
        player?.pause()
        player = nil
        state = .stopped
        
    }
    
    
    public func seek(toProgress progress: Double, _ completion: ((Bool)->Void)? = nil) {
        guard progress > 0.0 && progress < 1.0 else {
            return
        }
        
        let jumpToSec = duration * progress
        seek(toTime: jumpToSec, completion)
        
    }
    
    /// For fast forward and fast backword
    public func seek(withDelta dalta: TimeInterval) {
        let jumpToSec = currentTime + dalta
        
        guard jumpToSec > 0.0 && jumpToSec <= duration else {
            return
        }
        
        seek(toTime: jumpToSec)
    }
    
    public func seek(toTime: TimeInterval, _ completion: ((Bool)->Void)? = nil) {
        let jumoToTime = CMTimeMakeWithSeconds(toTime, Int32(NSEC_PER_SEC))
        
        player?.seek(to: jumoToTime, completionHandler: { (success) in
            completion?(success)
        })
    }
    
    // Change the player's rate to next rate speed
    public func changeToNextRate() {
        self.rate = self.getNextRateSpeed().rawValue
    }
    
    // A convenient method for getting the next rate speed
    public func getNextRateSpeed() -> AHAudioRateSpeed {
        guard let rateFloat = self.player?.rate else {
            return  AHAudioRateSpeed.one
        }
        guard let rate = AHAudioRateSpeed.init(rawValue: rateFloat) else {
            return  AHAudioRateSpeed.one
        }
        
        switch rate {
        case .one:
            return AHAudioRateSpeed.one_two_five
        case .one_two_five:
            return AHAudioRateSpeed.one_five
        case .one_five:
            return AHAudioRateSpeed.one_seven_five
        case .one_seven_five:
            return AHAudioRateSpeed.two
        case .two:
            return AHAudioRateSpeed.one
        }
    }
    
}

//MARK:- Setups
fileprivate extension AHAudioPlayer {
    // On each new play, KVO and notifications need to be setup again
    func setup() {
        // KVO
        setupKVO()
        
        // Notifications
        setupNotifications()
    }
    
    /* Note that NSNotifications posted by AVPlayerItem may be posted on a different thread from the one on which the observer was registered. */
    func setupNotifications() {
        // PlayerItem Nofitications
        let stalledHanlder = NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemPlaybackStalled, object: playerItem, queue: nil) { (notification) in
            print("PlaybackStalled")
            self.state = .paused
        }
        self.notificaitonHandlers.append(stalledHanlder)
        
        
        // NOTE: for this notification, the object parameter has to be playerItem otherwise it won't be fired. So passing playerItem for all related notifications is a good idea.
        let endTimeHanlder = NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: playerItem, queue: nil) { (notification) in
            print("DidPlayToEndTime")
            self.stop()
            self.delegate?.audioPlayerDidReachEnd(self)
            NotificationCenter.default.post(name: AHAudioPlayerDidReachEnd, object: nil)
            
        }
        self.notificaitonHandlers.append(endTimeHanlder)
        
        
        let failToEnd = NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemFailedToPlayToEndTime, object: playerItem, queue: nil) { (notification) in

            self.delegate?.audioPlayerFailedToReachEnd(self)
            NotificationCenter.default.post(name: AHAudioPlayerDidReachEnd, object: nil)
            self.stop()
            
        }
        self.notificaitonHandlers.append(failToEnd)
    }
    
    func setupKVO() {
        playerItem?.addObserver(self, forKeyPath: AHPlayerKeyPath.status, options: .new, context: &playerContext)
        playerItem?.addObserver(self, forKeyPath: AHPlayerKeyPath.keepUp, options: .new, context: &playerContext)
        playerItem?.addObserver(self, forKeyPath: AHPlayerKeyPath.bufferFull, options: .new, context: &playerContext)
        playerItem?.addObserver(self, forKeyPath: AHPlayerKeyPath.bufferEmpty, options: .new, context: &playerContext)
        
        // In case for audio route changes, though AVPlayer handles automatically, the player will paused when a headphone being taken out, rate becomes 0. So we need to know the rate and react to it.
        player?.addObserver(self, forKeyPath: "rate", options: .new, context: &playerRateContext)
    }
    
    func removeListeners() {
        removeObserver()
        removeNotifications()
        
    }
    
    func removeObserver() {
        playerItem?.removeObserver(self, forKeyPath: AHPlayerKeyPath.status)
        playerItem?.removeObserver(self, forKeyPath: AHPlayerKeyPath.keepUp)
        playerItem?.removeObserver(self, forKeyPath: AHPlayerKeyPath.bufferFull)
        playerItem?.removeObserver(self, forKeyPath: AHPlayerKeyPath.bufferEmpty)
        player?.removeObserver(self, forKeyPath: "rate")
    }
    
    func removeNotifications() {
        for handler in self.notificaitonHandlers {
            NotificationCenter.default.removeObserver(handler)
        }
        self.notificaitonHandlers.removeAll()
    }
}


//MARK: - KVO for playerItem
extension AHAudioPlayer {
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if context == &playerContext {
            handlePlayerItem(forKeyPath: keyPath, of: object, change: change, context: context)
            
        }else if context == &playerRateContext {
            handlePlayerRate(forKeyPath: keyPath, of: object, change: change, context: context)
        }else{
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
        
    }
    func handlePlayerRate(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let change = change else {
            return
        }
        guard let rate = change[NSKeyValueChangeKey.newKey] as? Float else {
            return
        }
        // ignore is the rate is 1.0
        // change state only when the rate is 0.0 in which user unplung its headphone
        if rate <= 0.0 {
            if self.state != .paused {
                self.state = .paused
            }
        }
    }
    
    
    func handlePlayerItem(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        guard let keyPath = keyPath else {
            return
        }
        guard let change = change else {
            return
        }
        
        switch keyPath {
        case AHPlayerKeyPath.status:
            statusDidChange(change)
        case AHPlayerKeyPath.keepUp:
            playbackLikelyToKeepUp(change)
        case AHPlayerKeyPath.bufferFull:
            playbackBufferFull(change)
        case AHPlayerKeyPath.bufferEmpty:
            playbackBufferEmpty(change)
        default:
            break
        }
    }
    
    func statusDidChange(_ change: [NSKeyValueChangeKey : Any]) {
        guard let statusInt = change[NSKeyValueChangeKey.newKey] as? Int else {
            return
        }
        guard let status = AVPlayerItemStatus(rawValue: statusInt)  else {
            return
        }
        
        
        if status == .readyToPlay {
            if self.isSeekToPlayMode && self.seekToTime > 0.0 {
                let time = self.seekToTime
                self.isSeekToPlayMode = false
                self.seekToTime = 0.0
                self.seek(toTime: time, { (ok) in
                    if ok {
                        self.resume()
                    }else{
                        self.stop()
                    }
                })
                
            }else{
                resume()
            }
            
        }else{
            stop()
        }
        
    }
    
    func playbackLikelyToKeepUp(_ change: [NSKeyValueChangeKey : Any]) {
        guard let canKeepUp = change[NSKeyValueChangeKey.newKey] as? Bool else {return}
        
        
        if canKeepUp && state != .playing{
            if !isManuallyPaused {
                print("automatically resume and play if user didn't pause it manually")
                resume()
            }
        }else{
            //            print("observer--can't keep up")
        }
        
    }
    
    func playbackBufferFull(_ change: [NSKeyValueChangeKey : Any]) {
//                print("isPlaybackBufferFull")
    }
    
    func playbackBufferEmpty(_ change: [NSKeyValueChangeKey : Any]?) {
        //        print("isPlaybackBufferEmpty")
    }
}

extension AHAudioPlayer {
    fileprivate func setupRemoteControl() {
        // one time setup
        if isSessionSetup == false {
            let audioSession = AVAudioSession.sharedInstance()
            do {
                try audioSession.setCategory(AVAudioSessionCategoryPlayback)
            } catch {
                print("Setting category to AVAudioSessionCategoryPlayback failed.")
                return
            }
            
            // Get the shared MPRemoteCommandCenter
            let commandCenter = MPRemoteCommandCenter.shared()
            
            commandCenter.togglePlayPauseCommand.addTarget(handler: {[weak self]  (_) -> MPRemoteCommandHandlerStatus in
                guard let strongSelf = self else {return .commandFailed}
                if strongSelf.state == .paused {
                    strongSelf.resume()
                    return .success
                }else if strongSelf.state == .playing{
                    strongSelf.pause()
                    return .success
                }else{
                    return .commandFailed
                }
                
            })
            
            
            // Add handler for Play Command
            commandCenter.playCommand.addTarget { [weak self] event in
                guard let strongSelf = self else {return .commandFailed}
                if strongSelf.state == .paused {
                    strongSelf.isPausedBeforeEnterBackground = false
                    strongSelf.resume()
                    strongSelf.isPausedBeforeEnterBackground = true
                    return .success
                }else{
                    return .commandFailed
                }
            }
            
            // Add handler for Pause Command
            commandCenter.pauseCommand.addTarget { [weak self] event in
                guard let strongSelf = self else {return .commandFailed}
                if strongSelf.state == .playing{
                    strongSelf.pause()
                    return .success
                }else{
                    return .commandFailed
                }
            }
            
            commandCenter.stopCommand.addTarget(handler: {[weak self] (_) -> MPRemoteCommandHandlerStatus in
                guard let strongSelf = self else {return .commandFailed}
                strongSelf.stop()
                return .commandFailed
            })
            
            
            commandCenter.nextTrackCommand.addTarget( handler: {[weak self] (_) -> MPRemoteCommandHandlerStatus in
                guard let strongSelf = self else {return .commandFailed}
                guard let delegate = strongSelf.delegate else {return .commandFailed}
                if delegate.audioPlayerShouldPlayNext(strongSelf) {
                    self?.updateNowPlaying()
                    return .success
                }else{
                    return .commandFailed
                }
            })
            
            commandCenter.previousTrackCommand.addTarget( handler: {[weak self] (_) -> MPRemoteCommandHandlerStatus in
                guard let strongSelf = self else {return .commandFailed}
                guard let delegate = strongSelf.delegate else {return .commandFailed}
                if delegate.audioPlayerShouldPlayPrevious(strongSelf) {
                    self?.updateNowPlaying()
                    return .success
                }else{
                    return .commandFailed
                }
            })
            
            commandCenter.changePlaybackRateCommand.addTarget(handler: {[weak self] (_) -> MPRemoteCommandHandlerStatus in
                guard let strongSelf = self else {return .commandFailed}
                guard let delegate = strongSelf.delegate else {return .commandFailed}
                if delegate.audioPlayerShouldChangePlaybackRate(strongSelf) {
                    return .success
                }else{
                    return .commandFailed
                }
            })
            
            
            commandCenter.seekForwardCommand.addTarget(handler: {[weak self] (_) -> MPRemoteCommandHandlerStatus in
                guard let strongSelf = self else {return .commandFailed}
                guard let delegate = strongSelf.delegate else {return .commandFailed}
                if delegate.audioPlayerShouldSeekForward(strongSelf) {
                    return .success
                }else{
                    return .commandFailed
                }
            })
            
            commandCenter.seekBackwardCommand.addTarget(handler: {[weak self] (_) -> MPRemoteCommandHandlerStatus in
                guard let strongSelf = self else {return .commandFailed}
                guard let delegate = strongSelf.delegate else {return .commandFailed}
                if delegate.audioPlayerShouldSeekBackward(strongSelf) {
                    return .success
                }else{
                    return .commandFailed
                }
            })
            
            
            // Enters Background
            NotificationCenter.default.addObserver(forName: NSNotification.Name.UIApplicationWillResignActive, object: nil, queue: nil, using: {[weak self] (_) in
                if self?.state == .paused {
                    self?.isPausedBeforeEnterBackground = true
                }
                self?.updateNowPlaying()
            })
            NotificationCenter.default.addObserver(forName: NSNotification.Name.UIApplicationDidBecomeActive, object: nil, queue: nil, using: {[weak self] (_) in
                self?.isPausedBeforeEnterBackground = false
            })
            
            isSessionSetup = true
        }
    }

}








