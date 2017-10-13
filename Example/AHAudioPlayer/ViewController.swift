//
//  ViewController.swift
//  AHAudioPlayer
//
//  Created by ivsall2012 on 07/20/2017.
//  Copyright (c) 2017 ivsall2012. All rights reserved.
//

import UIKit
import AHAudioPlayer

class ViewController: UIViewController {
    
    let delegate = AHFMAudioPlayerDelegate()
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        AHAudioPlayerManager.shared.delegate = delegate
        
        let url = URL(string: "https://mp3l.jamendo.com/?trackid=887202&format=mp31&from=app-devsite")
        AHAudioPlayerManager.shared.play(trackId: 0, trackURL: url!)
    }

}










