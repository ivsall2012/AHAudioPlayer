//
//  AHFMAudioPlayerDelegate.swift
//  AHAudioPlayer
//
//  Created by Andy Tong on 9/28/17.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import Foundation
import AHAudioPlayer

let testAudioURL1 = "https://mp3l.jamendo.com/?trackid=887202&format=mp31&from=app-devsite"
let testAudioURL2 = "https://firebasestorage.googleapis.com/v0/b/savori-6387d.appspot.com/o/All_Inuyasha_Openings.mp3?alt=media&token=8e78127b-4a0b-4f4d-b8cc-a7256a10457c"

let testAudioURL3 = "https://www.audiosear.ch/media/77d4ed5635bfe5946a986f2e19f3c4fa/0/public/audio_file/448474/321933835-irishtimes-business-pay-commission-flash-points-athlone-town-betting-scandal.mp3"

let testAudioURL4 = "https://www.audiosear.ch/media/a45371838fbaa81f39a2c877b54dfd8c/0/public/audio_file/104285/media.mp3"

let Tracks = [testAudioURL1,testAudioURL2,testAudioURL3,testAudioURL4]
let AlbumnNames = ["Albumn_1","Albumn_2","Albumn_3","Albumn_4"]
let TrackNames = ["testAudioURL1","testAudioURL2","testAudioURL3","testAudioURL4"]
let TrackImages = [#imageLiteral(resourceName: "track_1"),#imageLiteral(resourceName: "track_2"),#imageLiteral(resourceName: "track_3"),#imageLiteral(resourceName: "track_4")]


class AHFMAudioPlayerDelegate: NSObject, AHAudioPlayerMangerDelegate {
    func playerManger(_ manager: AHAudioPlayerManager, updateForTrackId trackId: Int, duration: TimeInterval){
        print("\(getTrackTitle(trackId: trackId)) update duration:\(duration)")
    }
    func playerManger(_ manager: AHAudioPlayerManager, updateForTrackId trackId: Int, playedProgress: TimeInterval){
        print("\(getTrackTitle(trackId: trackId)) update playedProgress:\(playedProgress)")
    }
    func playerManger(_ manager: AHAudioPlayerManager, updateForTrackId trackId: Int, completion: (_ coverImage: UIImage?)->Void){
        completion(getAlbumnCover(trackId: trackId))
    }
    
    /// The following five are for audio background mode
    /// Both requiring the delegate to return a dict [trackId: id, trackURL: URL]
    /// trackId is Int, trackURL is URL
    func playerMangerGetPreviousTrackInfo(_ manager: AHAudioPlayerManager, currentTrackId: Int) -> [String: Any] {
        return getPrevious(currentTrackId)
    }
    func playerMangerGetNextTrackInfo(_ manager: AHAudioPlayerManager, currentTrackId: Int) -> [String: Any]{
        return getNext(currentTrackId)
    }
    func playerMangerGetTrackTitle(_ player: AHAudioPlayerManager, trackId: Int) -> String?{
        return getTrackTitle(trackId: trackId)
    }
    func playerMangerGetAlbumTitle(_ player: AHAudioPlayerManager, trackId: Int) -> String?{
        return nil
    }
    func playerMangerGetAlbumCover(_ player: AHAudioPlayerManager, trackId: Int, _ callback: (_ coverImage: UIImage?)->Void){
        callback(getAlbumnCover(trackId: trackId))
    }
}


extension AHFMAudioPlayerDelegate {
    
    func getNext(_ current: Int) -> [String: Any] {
        guard current >= 0 && current < Tracks.count - 1 else {
            return [:]
        }
        let url = URL(string: Tracks[current + 1])
        let id = current + 1
        return ["trackId": id, "trackURL": url!]
    }
    func getPrevious(_ current: Int) -> [String: Any] {
        guard current > 0 && current < Tracks.count else {
            return [:]
        }
        let url = URL(string: Tracks[current - 1])
        let id = current - 1
        return ["trackId": id, "trackURL": url!]
    }
    
    func getTrackTitle(trackId: Int) -> String {
        return TrackNames[trackId]
    }
    func getAlbumnTitle(trackId: Int) -> String{
        return AlbumnNames[trackId]
    }
    func getAlbumnCover(trackId: Int) -> UIImage {
        return TrackImages[trackId]
    }
}
