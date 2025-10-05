//
//  MurmurWidgetsBundle.swift
//  MurmurWidgets
//
//  Created by Aidan Cornelius-Bell on 2/10/2025.
//

import WidgetKit
import SwiftUI

@main
struct MurmurWidgetsBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 18.0, *) {
            LogSymptomControl()
            LogActivityControl()
        }
    }
}
