//
//  ContentView.swift
//  ConvertAgoraAudioToAVAudioAssetWriterFormat
//
//  Created by Shaun Hubbard on 4/5/23.
//

import SwiftUI

struct ContentView: View {
    @StateObject var rtc = RTCManager()
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            if rtc.myUid == 0 {
                Text("Not connected")
            } else {
                Text("Connected")
            }
            
            if rtc.mute {
                Button("Publish", role: .none) {
                    rtc.mute = false
                }.buttonStyle(.bordered)
            } else {
            
                Button("Un Publish", role: .destructive) {
                    rtc.mute = true
                }.buttonStyle(.bordered)
                
            }
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
