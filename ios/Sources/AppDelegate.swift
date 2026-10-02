import UIKit
import BluetoothLibrary

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        RingBLE.shared.start()

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UINavigationController(rootViewController: ScanViewController())
        window.makeKeyAndVisible()
        self.window = window
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // The ring only streams sensor data while the switch is open; drop it when
        // we leave the foreground so we don't drain the battery.
        RingBLE.shared.setSensor(false)
    }

    func applicationWillTerminate(_ application: UIApplication) {
        RingBLE.shared.setSensor(false)
        RingBLE.shared.stop()
    }
}