import Testing
import SwiftUI
@testable import DuoTest

@MainActor
struct BarOptionsTests {
    @Test func defaultsShowNoBars() {
        let options = BarOptions()
        #expect(options.navigationBarVisibility == .hidden)
        #expect(options.tabBarVisibility == .hidden)
        #expect(options.forceNavigationBar)
    }

    @Test func forcedNavigationBarIsVisibleWhenItHasContent() {
        var options = BarOptions()
        options.toolbar = true
        #expect(options.navigationBarVisibility == .visible)
        options.toolbar = false
        options.title = true
        #expect(options.navigationBarVisibility == .visible)
    }

    @Test func unforcedNavigationBarIsAlwaysAutomatic() {
        var options = BarOptions()
        options.forceNavigationBar = false
        #expect(options.navigationBarVisibility == .automatic)
        options.toolbar = true
        #expect(options.navigationBarVisibility == .automatic)
    }

    @Test func tabBarFollowsItsSwitch() {
        var options = BarOptions()
        options.tabBar = true
        #expect(options.tabBarVisibility == .visible)
    }
}
