//  AwfulVerticalTabBarController.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

/**
 * An AwfulVerticalTabBarController is a container view controller with a permanently visible tab bar along its left edge.
 */
@interface AwfulVerticalTabBarController : UIViewController

/**
 * Returns an initialized AwfulVerticalTabBarController.
 *
 * @param viewControllers An array of UIViewController objects.
 */
- (id)initWithViewControllers:(NSArray *)viewControllers;

/**
 * An array of UIViewController objects. They will be represented by their `tabBarItem`.
 */
@property (copy, nonatomic) NSArray *viewControllers;

/**
 * The selected view controller.
 */
@property (strong, nonatomic) UIViewController *selectedViewController;

/**
 * The index of the selected view controler in the `viewControllers` array.
 */
@property (assign, nonatomic) NSUInteger selectedIndex;

@end
