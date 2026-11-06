import Testing
import SwiftUI
@testable import DuoDevOverlayDemo

@MainActor
struct BarOptionsTests {
    @Test func defaultsShowNoBars() {
        let options = BarOptions()
        #expect(options.navigationBarVisibility == .hidden)
        #expect(options.tabBarVisibility == .hidden)
    }

    @Test func navigationBarIsVisibleWhenItHasContent() {
        var options = BarOptions()
        options.toolbar = true
        #expect(options.navigationBarVisibility == .visible)
        options.toolbar = false
        options.title = true
        #expect(options.navigationBarVisibility == .visible)
    }

    @Test func tabBarFollowsItsSwitch() {
        var options = BarOptions()
        options.tabBar = true
        #expect(options.tabBarVisibility == .visible)
    }
}
