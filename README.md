# AHAudioPlayer
## Usage
### Play
```Swift
let url = URL(string: "https://mp3l.jamendo.com/?trackid=887202&format=mp31&from=app-devsite")
AHAudioPlayerManager.shared.play(trackId: 0, trackURL: url!)
```

### Acive Monitoring for UI related components
```Swift
let timer = Timer(timeInterval: 0.1, target: self, selector: #selector(updatePlayer), userInfo: nil, repeats: true)
RunLoop.main.add(timer!, forMode: .commonModes)

func updatePlayer() {
let loadedProgress = CGFloat(AHAudioPlayerManager.shared.loadedProgress)
let progress = AHAudioPlayerManager.shared.progress
let currentTime = AHAudioPlayerManager.shared.currentTimePretty
let duration = AHAudioPlayerManager.shared.durationPretty
let speedStr = AHAudioPlayerManager.shared.rate.rawValue > 0 ? "\(AHAudioPlayerManager.shared.rate.rawValue)x" : "1.0x"
}
```
### Passive Monitoring
#### A. Using delegate for updating local database and fetching datas for background mode
```Swift
/// Update every 10s after the track startd to play.
func playerManger(_ manager: AHAudioPlayerManager, updateForTrackId trackId: Int, duration: TimeInterval)

/// Update every 10s after the track startd to play, additionally when paused, resume, and right before stop.
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
```

#### B. Using notification for specific UI components to react to events sent out by the playerManger
```Swift
public let AHAudioPlayerDidStartToPlay = Notification.Name("AHAudioPlayerDidStartToPlay")

public let AHAudioPlayerDidChangeState = Notification.Name("AHAudioPlayerDidChangeState")

/// Sent every time a track is being played
public let AHAudioPlayerDidSwitchPlay = Notification.Name("AHAudioPlayerDidSwitchPlay")

public let AHAudioPlayerDidReachEnd = Notification.Name("AHAudioPlayerDidReachEnd")

public let AHAudioPlayerFailedToReachEnd = Notification.Name("AHAudioPlayerFailedToReachEnd")
```
## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements
iOS 8.0+
## Installation

AHAudioPlayer is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "AHAudioPlayer"
```

## Author

Andy Tong, ivsall2012@gmail.com

## License

AHAudioPlayer is available under the MIT license. See the LICENSE file for more info.

