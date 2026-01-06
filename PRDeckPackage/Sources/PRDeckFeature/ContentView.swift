import SwiftUI

public struct ContentView: View {
    @ObservedObject private var dataController: DataController

    public init(dataController: DataController) {
        self.dataController = dataController
    }

    public var body: some View {
        RootView(dataController: dataController)
            .frame(minWidth: 420, idealWidth: 420, minHeight: 360, idealHeight: 440)
    }
}
