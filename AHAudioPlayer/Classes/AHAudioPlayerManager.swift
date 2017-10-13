//
//  AHAudioPlayerManager.swift
//  Pods
//
//  Created by Andy Tong on 7/20/17.
//
//

import Foundation
import MediaPlayer

public let AHAudioPlayerDidStartToPlay = Notification.Name("AHAudioPlayerDidStartToPlay")

public let AHAudioPlayerDidChangeState = Notification.Name("AHAudioPlayerDidChangeState")

/// Sent every time a track is being played
public let AHAudioPlayerDidSwitchPlay = Notification.Name("AHAudioPlayerDidSwitchPlay")

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

@objc public protocol AHAudioPlayerMangerDelegate: class {
    /// Update every 10s after the track startd to play.
    func playerManger(_ manager: AHAudioPlayerManager, updateForTrackId trackId: Int, duration: TimeInterval)
    
    /// Update every 10s after the track startd to play, additionally when paused, resume, and right before anything stop.
    func playerManger(_ manager: AHAudioPlayerManager, updateForTrackId trackId: Int, playedProgress: TimeInterval)
    
    ///###### The following five are for audio background mode
    /// Return a dict should include ['trackId': Int, 'trackURL': URL]. Return [:] if there's none or network is broken.
    func playerMangerGetPreviousTrackInfo(_ manager: AHAudioPlayerManager, currentTrackId: Int) -> [String: Any]
    
    /// Return a dict should include ['trackId': Int, 'trackURL': URL]. Return [:] if there's none or network is broken.
    func playerMangerGetNextTrackInfo(_ manager: AHAudioPlayerManager, currentTrackId: Int) -> [String: Any]
    
    func playerMangerGetTrackTitle(_ player: AHAudioPlayerManager, trackId: Int) -> String?
    
    func playerMangerGetAlbumTitle(_ player: AHAudioPlayerManager, trackId: Int) -> String?
    
    func playerMangerGetAlbumCover(_ player: AHAudioPlayerManager,trackId: Int, _ callback: @escaping(_ coverImage: UIImage?)->Void)
    ///######
}


struct PlayerItem: Equatable {
    var id: Int?
    var url: URL
    var image: UIImage?
    
    public static func ==(lhs: PlayerItem, rhs: PlayerItem) -> Bool {
        return lhs.url == rhs.url || lhs.id == rhs.id
    }
    
}


public class AHAudioPlayerManager: NSObject {
    public static let shared = AHAudioPlayerManager()
    
    public override init() {
        super.init()
        AHAudioPlayer.shared.delegate = self
    }
    
    public weak var delegate: AHAudioPlayerMangerDelegate?
    
    public var playingTrackId: Int? {
        return self.playingItem?.id
    }
    public var playingTrackURL: URL? {
        return self.playingItem?.url
    }
    
    fileprivate(set) var playingItem: PlayerItem?
    
    /// Timer used in background mode and save progress periodically
    fileprivate var timer: Timer?
    
    /// For fast backward/forward delta in seconds
    fileprivate var fastDelta = 10.0
}

//MARK:- Player States
extension AHAudioPlayerManager {
    public var state: AHAudioPlayerState {
        
        return AHAudioPlayer.shared.state
    }
    
    public var muted: Bool {
        set {
            AHAudioPlayer.shared.muted = muted
        }
        
        get {
            return AHAudioPlayer.shared.muted
        }
    }
    
    public var rate: AHAudioRateSpeed {
        set {
            AHAudioPlayer.shared.rate = newValue.rawValue
        }
        
        get {
            guard let rate = AHAudioRateSpeed(rawValue: AHAudioPlayer.shared.rate) else {
                return AHAudioRateSpeed.one
            }
            return rate
        }
    }
    
    
    
    /// this value has to be between [0,1]
    public var volumn: Float {
        set {
            AHAudioPlayer.shared.volumn = newValue
        }
        
        get {
            return AHAudioPlayer.shared.volumn
        }
    }
    
    public var durationPretty: String {
        return AHAudioPlayer.shared.durationPretty
    }
    
    public var duration: TimeInterval {
        return AHAudioPlayer.shared.duration
    }
    
    /// you might need to setup a timer to read this as a progress
    public var currentTimePretty: String {
        return AHAudioPlayer.shared.currentTimePretty
    }
    
    public var currentTime: TimeInterval {
        return AHAudioPlayer.shared.currentTime
    }
    
    /// curreent plackback progress
    public var progress: Double {
        return AHAudioPlayer.shared.progress
    }
    /// progress downloaded
    public var loadedProgress: Double {
        return AHAudioPlayer.shared.loadedProgress
    }
}

//MARK:- Play
extension AHAudioPlayerManager {
    /// toProgress should be in seconds, NOT in percentage.
    public func play(trackId: Int?, trackURL: URL, toTime: TimeInterval? = nil) {
        self.playingItem = PlayerItem(id: trackId, url: trackURL, image: nil)
        
        if timer != nil {
            timer?.invalidate()
            timer = nil
        }
        //cached progress periodically
        timer = Timer(timeInterval: 10, target: self, selector: #selector(self.updateInBackground), userInfo: nil, repeats: true)
        RunLoop.main.add(timer!, forMode: RunLoopMode.commonModes)
        
        
        AHAudioPlayer.shared.play(url: trackURL, toTime: toTime)
        
        
    }
}


//MARK:- Playback Control
extension AHAudioPlayerManager {
    public func pause() {
        AHAudioPlayer.shared.pause()
        
        if timer != nil {
            timer?.invalidate()
            timer = nil
        }
        
        updateTrackPlayedProgress()
        
    }
    
    public func resume() {
        AHAudioPlayer.shared.resume()
        
        if timer != nil {
            timer?.invalidate()
            timer = nil
        }
        
        //cached progress periodically
        timer = Timer(timeInterval: 10, target: self, selector: #selector(self.updateInBackground), userInfo: nil, repeats: true)
        RunLoop.main.add(timer!, forMode: RunLoopMode.commonModes)
        
    }
    
    public func stop() {
        updateTrackPlayedProgress()
        AHAudioPlayer.shared.stop()
        
        if timer != nil {
            timer?.invalidate()
            timer = nil
        }
    }
    
    public func seekBackward() {
        AHAudioPlayer.shared.seek(withDelta: -fastDelta)
    }
    public func seekForward() {
        AHAudioPlayer.shared.seek(withDelta: fastDelta)
    }
    public func seekToPercent(_ percentage: Double, _ completion: ((Bool)->Void)? = nil) {
        AHAudioPlayer.shared.seek(toProgress: percentage, completion)
    }
    
    public func changeToNextRate() {
        AHAudioPlayer.shared.changeToNextRate()
    }
}


//MARK:- Helper
extension AHAudioPlayerManager {
    fileprivate func updateTrackDuration() {
        guard self.duration > 0 else {
            return
        }
        guard let item = self.playingItem else {
            return
        }
        guard let id = item.id else {
            return
        }
        self.delegate?.playerManger(self, updateForTrackId: id, duration: self.duration)
    }
    
    fileprivate func updateTrackPlayedProgress() {
        guard let item = self.playingItem else {
            return
        }
        guard let id = item.id else {
            return
        }
        self.delegate?.playerManger(self, updateForTrackId: id, playedProgress: self.currentTime)
    }
}




extension AHAudioPlayerManager: AHAudioPlayerDelegate {

    @objc func updateInBackground() {
        updateTrackPlayedProgress()
    }
    
    func audioPlayerDidStartToPlay(_ player: AHAudioPlayer) {
        updateTrackPlayedProgress()
        updateTrackDuration()
    }
    func audioPlayerDidReachEnd(_ player: AHAudioPlayer) {
        stop()
        
        guard let nextItem = self.getNextItem() else {
            return
        }
        self.playingItem = nextItem
        self.play(trackId: nextItem.id, trackURL: nextItem.url)
    }
    
    func audioPlayerShouldPlayNext(_ player: AHAudioPlayer) -> Bool{
        guard let nextItem = self.getNextItem() else {
            return false
        }
        stop()
        self.playingItem = nextItem
        self.play(trackId: nextItem.id, trackURL: nextItem.url)
        return true
    }
    func audioPlayerShouldPlayPrevious(_ player: AHAudioPlayer) -> Bool{
        guard let previousItem = self.getPrevisouItem() else {
            return false
        }
        stop()
        self.playingItem = previousItem
        self.play(trackId: previousItem.id, trackURL: previousItem.url)
        return true
    }
    func audioPlayerShouldChangePlaybackRate(_ player: AHAudioPlayer) -> Bool{
        self.changeToNextRate()
        return true
    }
    func audioPlayerShouldSeekForward(_ player: AHAudioPlayer) -> Bool{
        seekForward()
        return true
    }
    func audioPlayerShouldSeekBackward(_ player: AHAudioPlayer) -> Bool{
        seekBackward()
        return true
    }
    
    func audioPlayerGetTrackTitle(_ player: AHAudioPlayer) -> String?{
        guard let item = self.playingItem else {
            return nil
        }
        guard let id = item.id else {
            return nil
        }
        return self.delegate?.playerMangerGetTrackTitle(self, trackId: id)
    }
    func audioPlayerGetAlbumTitle(_ player: AHAudioPlayer) -> String?{
        guard let item = self.playingItem else {
            return nil
        }
        guard let id = item.id else {
            return nil
        }
        
        return self.delegate?.playerMangerGetAlbumTitle(self, trackId: id)
    }
    func audioPlayerGetAlbumCover(_ player: AHAudioPlayer, _ callback: @escaping (UIImage?) -> Void) {
        guard let item = self.playingItem else {
            callback(nil)
            return
        }
        guard let id = item.id else {
            callback(nil)
            return
        }
        self.delegate?.playerMangerGetAlbumCover(self, trackId: id, { (image) in
            callback(image)
        })
    }
    
}

//MARK:- Helper Methods
extension AHAudioPlayerManager {
    fileprivate func getNextItem() -> PlayerItem? {
        guard let delegate = self.delegate else {
            return nil
        }
        guard let item = self.playingItem else {
            return nil
        }
        guard let id = item.id else {
            return nil
        }
        
        let dict = delegate.playerMangerGetNextTrackInfo(self, currentTrackId: id)
        if let trackId = dict["trackId"] as? Int, let trackURL = dict["trackURL"] as? URL {
            let item = PlayerItem(id: trackId, url: trackURL, image: nil)
            return item
        }else{
            return nil
        }
    }
    
    fileprivate func getPrevisouItem() -> PlayerItem? {
        guard let delegate = self.delegate else {
            return nil
        }
        guard let item = self.playingItem else {
            return nil
        }
        guard let id = item.id else {
            return nil
        }
        
        let dict = delegate.playerMangerGetPreviousTrackInfo(self,currentTrackId: id)
        if let trackId = dict["trackId"] as? Int, let trackURL = dict["trackURL"] as? URL {
            let item = PlayerItem(id: trackId, url: trackURL, image: nil)
            return item
        }else{
            return nil
        }
    }
}

