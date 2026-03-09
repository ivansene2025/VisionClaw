import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

    /// The "AccentColor" asset catalog color resource.
    static let accent = DeveloperToolsSupport.ColorResource(name: "AccentColor", bundle: resourceBundle)

    /// The "appPrimaryColor" asset catalog color resource.
    static let appPrimary = DeveloperToolsSupport.ColorResource(name: "appPrimaryColor", bundle: resourceBundle)

    /// The "destructiveBackground" asset catalog color resource.
    static let destructiveBackground = DeveloperToolsSupport.ColorResource(name: "destructiveBackground", bundle: resourceBundle)

    /// The "destructiveForeground" asset catalog color resource.
    static let destructiveForeground = DeveloperToolsSupport.ColorResource(name: "destructiveForeground", bundle: resourceBundle)

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

    /// The "cameraAccessIcon" asset catalog image resource.
    static let cameraAccessIcon = DeveloperToolsSupport.ImageResource(name: "cameraAccessIcon", bundle: resourceBundle)

    /// The "smartGlassesIcon" asset catalog image resource.
    static let smartGlassesIcon = DeveloperToolsSupport.ImageResource(name: "smartGlassesIcon", bundle: resourceBundle)

    /// The "soundIcon" asset catalog image resource.
    static let soundIcon = DeveloperToolsSupport.ImageResource(name: "soundIcon", bundle: resourceBundle)

    /// The "tapIcon" asset catalog image resource.
    static let tapIcon = DeveloperToolsSupport.ImageResource(name: "tapIcon", bundle: resourceBundle)

    /// The "videoIcon" asset catalog image resource.
    static let videoIcon = DeveloperToolsSupport.ImageResource(name: "videoIcon", bundle: resourceBundle)

    /// The "walkingIcon" asset catalog image resource.
    static let walkingIcon = DeveloperToolsSupport.ImageResource(name: "walkingIcon", bundle: resourceBundle)

}

// MARK: - Color Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

    /// The "AccentColor" asset catalog color.
    static var accent: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .accent)
#else
        .init()
#endif
    }

    /// The "appPrimaryColor" asset catalog color.
    static var appPrimary: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .appPrimary)
#else
        .init()
#endif
    }

    /// The "destructiveBackground" asset catalog color.
    static var destructiveBackground: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .destructiveBackground)
#else
        .init()
#endif
    }

    /// The "destructiveForeground" asset catalog color.
    static var destructiveForeground: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .destructiveForeground)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    /// The "AccentColor" asset catalog color.
    static var accent: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .accent)
#else
        .init()
#endif
    }

    /// The "appPrimaryColor" asset catalog color.
    static var appPrimary: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .appPrimary)
#else
        .init()
#endif
    }

    /// The "destructiveBackground" asset catalog color.
    static var destructiveBackground: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .destructiveBackground)
#else
        .init()
#endif
    }

    /// The "destructiveForeground" asset catalog color.
    static var destructiveForeground: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .destructiveForeground)
#else
        .init()
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    /// The "AccentColor" asset catalog color.
    static var accent: SwiftUI.Color { .init(.accent) }

    /// The "appPrimaryColor" asset catalog color.
    static var appPrimary: SwiftUI.Color { .init(.appPrimary) }

    /// The "destructiveBackground" asset catalog color.
    static var destructiveBackground: SwiftUI.Color { .init(.destructiveBackground) }

    /// The "destructiveForeground" asset catalog color.
    static var destructiveForeground: SwiftUI.Color { .init(.destructiveForeground) }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    /// The "AccentColor" asset catalog color.
    static var accent: SwiftUI.Color { .init(.accent) }

    /// The "appPrimaryColor" asset catalog color.
    static var appPrimary: SwiftUI.Color { .init(.appPrimary) }

    /// The "destructiveBackground" asset catalog color.
    static var destructiveBackground: SwiftUI.Color { .init(.destructiveBackground) }

    /// The "destructiveForeground" asset catalog color.
    static var destructiveForeground: SwiftUI.Color { .init(.destructiveForeground) }

}
#endif

// MARK: - Image Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    /// The "cameraAccessIcon" asset catalog image.
    static var cameraAccessIcon: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .cameraAccessIcon)
#else
        .init()
#endif
    }

    /// The "smartGlassesIcon" asset catalog image.
    static var smartGlassesIcon: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .smartGlassesIcon)
#else
        .init()
#endif
    }

    /// The "soundIcon" asset catalog image.
    static var soundIcon: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .soundIcon)
#else
        .init()
#endif
    }

    /// The "tapIcon" asset catalog image.
    static var tapIcon: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .tapIcon)
#else
        .init()
#endif
    }

    /// The "videoIcon" asset catalog image.
    static var videoIcon: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .videoIcon)
#else
        .init()
#endif
    }

    /// The "walkingIcon" asset catalog image.
    static var walkingIcon: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .walkingIcon)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    /// The "cameraAccessIcon" asset catalog image.
    static var cameraAccessIcon: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .cameraAccessIcon)
#else
        .init()
#endif
    }

    /// The "smartGlassesIcon" asset catalog image.
    static var smartGlassesIcon: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .smartGlassesIcon)
#else
        .init()
#endif
    }

    /// The "soundIcon" asset catalog image.
    static var soundIcon: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .soundIcon)
#else
        .init()
#endif
    }

    /// The "tapIcon" asset catalog image.
    static var tapIcon: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .tapIcon)
#else
        .init()
#endif
    }

    /// The "videoIcon" asset catalog image.
    static var videoIcon: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .videoIcon)
#else
        .init()
#endif
    }

    /// The "walkingIcon" asset catalog image.
    static var walkingIcon: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .walkingIcon)
#else
        .init()
#endif
    }

}
#endif

// MARK: - Thinnable Asset Support -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ColorResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if AppKit.NSColor(named: NSColor.Name(thinnableName), bundle: bundle) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIColor(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}
#endif

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ImageResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if bundle.image(forResource: NSImage.Name(thinnableName)) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIImage(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

