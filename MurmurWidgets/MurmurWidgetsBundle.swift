// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// MurmurWidgetsBundle.swift
// Created by Aidan Cornelius-Bell on 02/10/2025.
// Widget extension bundle definition.
//
import WidgetKit
import SwiftUI

@main
struct MurmurWidgetsBundle: WidgetBundle {
    var body: some Widget {
        LogSymptomControl()
        LogActivityControl()
    }
}
