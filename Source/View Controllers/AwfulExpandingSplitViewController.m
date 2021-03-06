//  AwfulExpandingSplitViewController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulExpandingSplitViewController.h"

@interface AwfulExpandingSplitViewController ()

@property (strong, nonatomic) NSLayoutConstraint *expandedDetailViewControllerConstraint;

@end

@implementation AwfulExpandingSplitViewController
{
    NSMutableArray *_masterViewControllerConstraints;
    NSMutableArray *_detailViewControllerConstraints;
}

- (id)initWithViewControllers:(NSArray *)viewControllers
{
    if (!(self = [super initWithNibName:nil bundle:nil])) return nil;
    _viewControllers = [viewControllers copy];
    return self;
}

- (void)loadView
{
    self.view = [UIView new];
    self.view.backgroundColor = [UIColor colorWithRed:0.118 green:0.518 blue:0.686 alpha:1];
    _masterViewControllerConstraints = [NSMutableArray new];
    _detailViewControllerConstraints = [NSMutableArray new];
    if (self.viewControllers.count > 0) {
        [self replaceMasterViewController:nil withViewController:self.viewControllers[0]];
    }
    if (self.detailViewController) {
        [self replaceDetailViewController:nil withViewController:self.detailViewController];
    }
}

- (void)setViewControllers:(NSArray *)viewControllers
{
    if (_viewControllers == viewControllers) return;
    UIViewController *oldMasterViewController = _viewControllers[0];
    UIViewController *oldDetailViewController = self.detailViewController;
    _viewControllers = [viewControllers copy];
    [self ensureToggleDetailExpandedLeftBarButtonItem];
    if ([self isViewLoaded]) {
        UIViewController *newMasterViewController = _viewControllers[0];
        if (![oldMasterViewController isEqual:newMasterViewController]) {
            [self replaceMasterViewController:oldMasterViewController withViewController:newMasterViewController];
        }
        if (_viewControllers.count > 1) {
            [self replaceDetailViewController:oldDetailViewController withViewController:_viewControllers[1]];
        }
    }
}

- (void)ensureToggleDetailExpandedLeftBarButtonItem
{
    UINavigationItem *navigationItem = self.detailViewController.navigationItem;
    if ([self.detailViewController isKindOfClass:[UINavigationController class]]) {
        UIViewController *root = ((UINavigationController *)self.detailViewController).viewControllers.firstObject;
        navigationItem = root.navigationItem;
    }
    navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                                     target:self
                                                                                     action:@selector(toggleDetailExpanded)];
}

- (void)toggleDetailExpanded
{
    [self setDetailExpanded:!self.detailExpanded animated:YES];
}

- (void)replaceMasterViewController:(UIViewController *)oldMasterViewController
                 withViewController:(UIViewController *)newMasterViewController
{
    [oldMasterViewController willMoveToParentViewController:nil];
    [self addChildViewController:newMasterViewController];
    [self.view removeConstraints:_masterViewControllerConstraints];
    [_masterViewControllerConstraints removeAllObjects];
    [oldMasterViewController.view removeFromSuperview];
    newMasterViewController.view.translatesAutoresizingMaskIntoConstraints = NO;
    newMasterViewController.view.clipsToBounds = YES;
    [self.view insertSubview:newMasterViewController.view atIndex:0];
    NSDictionary *views = @{ @"master": newMasterViewController.view };
    [_masterViewControllerConstraints addObjectsFromArray:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[master(==320)]"
                                             options:0
                                             metrics:nil
                                               views:views]];
    [_masterViewControllerConstraints addObjectsFromArray:
     [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[master]|" options:0 metrics:nil views:views]];
    [self.view addConstraints:_masterViewControllerConstraints];
    [oldMasterViewController removeFromParentViewController];
    [newMasterViewController didMoveToParentViewController:self];
    if (!self.detailExpanded) {
        [self setNeedsStatusBarAppearanceUpdate];
    }
}

- (void)replaceDetailViewController:(UIViewController *)oldDetailViewController
                 withViewController:(UIViewController *)newDetailViewController
{
    [oldDetailViewController willMoveToParentViewController:nil];
    [self addChildViewController:newDetailViewController];
    [self.view removeConstraints:_detailViewControllerConstraints];
    [_detailViewControllerConstraints removeAllObjects];
    if (self.expandedDetailViewControllerConstraint) {
        [self.view removeConstraint:self.expandedDetailViewControllerConstraint];
        self.expandedDetailViewControllerConstraint = nil;
    }
    [oldDetailViewController.view removeFromSuperview];
    newDetailViewController.view.translatesAutoresizingMaskIntoConstraints = NO;
    newDetailViewController.view.clipsToBounds = YES;
    [self.view addSubview:newDetailViewController.view];
    UIViewController *master = self.viewControllers[0];
    NSDictionary *views = @{ @"master": master.view,
                             @"detail": newDetailViewController.view };
    [_detailViewControllerConstraints addObjectsFromArray:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:[master]-1@500-[detail]|"
                                             options:0
                                             metrics:nil
                                               views:views]];
    [_detailViewControllerConstraints addObjectsFromArray:
     [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[detail]|" options:0 metrics:nil views:views]];
    [self.view addConstraints:_detailViewControllerConstraints];
    if (self.detailExpanded) {
        [self constrainDetailViewExpanded];
    }
    [oldDetailViewController removeFromParentViewController];
    [newDetailViewController didMoveToParentViewController:self];
    if (self.detailExpanded) {
        [self setNeedsStatusBarAppearanceUpdate];
    }
}

- (void)constrainDetailViewExpanded
{
    UIView *detail = self.detailViewController.view;
    self.expandedDetailViewControllerConstraint = [NSLayoutConstraint constraintWithItem:detail
                                                                               attribute:NSLayoutAttributeLeft
                                                                               relatedBy:NSLayoutRelationEqual
                                                                                  toItem:self.view
                                                                               attribute:NSLayoutAttributeLeft
                                                                              multiplier:1
                                                                                constant:0];
    [self.view addConstraint:self.expandedDetailViewControllerConstraint];
}

- (void)setDetailExpanded:(BOOL)detailExpanded
{
    [self setDetailExpanded:detailExpanded animated:NO];
}

- (void)setDetailExpanded:(BOOL)detailExpanded animated:(BOOL)animated
{
    if (_detailExpanded == detailExpanded) return;
    _detailExpanded = detailExpanded;
    if (detailExpanded) {
        [self constrainDetailViewExpanded];
    } else {
        [self.view removeConstraint:self.expandedDetailViewControllerConstraint];
        self.expandedDetailViewControllerConstraint = nil;
    }
    [UIView animateWithDuration:(animated ? 0.3 : 0) animations:^{
        [self.view layoutIfNeeded];
    }];
    [self setNeedsStatusBarAppearanceUpdate];
}

- (UIViewController *)detailViewController
{
    return self.viewControllers.count > 1 ? self.viewControllers[1] : nil;
}

- (void)setDetailViewController:(UIViewController *)detailViewController
{
    if (detailViewController) {
        self.viewControllers = @[ self.viewControllers[0], detailViewController ];
    } else {
        self.viewControllers = @[ self.viewControllers[0] ];
    }
}

- (UITabBarItem *)tabBarItem
{
    UIViewController *masterViewController = self.viewControllers[0];
    return masterViewController.tabBarItem;
}

- (UIViewController *)childViewControllerForStatusBarStyle
{
    if (self.detailExpanded) {
        return self.detailViewController;
    } else {
        return self.viewControllers[0];
    }
}

#pragma mark State preservation and restoration

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super encodeRestorableStateWithCoder:coder];
    [coder encodeObject:self.viewControllers forKey:ViewControllersKey];
    [coder encodeBool:self.detailExpanded forKey:DetailExpandedKey];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super decodeRestorableStateWithCoder:coder];
    self.viewControllers = [coder decodeObjectForKey:ViewControllersKey];
    self.detailExpanded = [coder decodeBoolForKey:DetailExpandedKey];
}

- (void)applicationFinishedRestoringState
{
    [super applicationFinishedRestoringState];
    
    // If the detailViewController is a UINavigationController, it has no child view controllers as of -decodeRestorableStateWithCoder:. So it doesn't get its left bar button item set. That feels wrong to me, but this works if we do it here, so here we go.
    [self ensureToggleDetailExpandedLeftBarButtonItem];
}

static NSString * const ViewControllersKey = @"AwfulViewControllers";
static NSString * const DetailExpandedKey = @"AwfulDetailExpanded";

@end

@implementation UIViewController (AwfulExpandingSplitViewController)

- (AwfulExpandingSplitViewController *)expandingSplitViewController
{
    UIViewController *maybe = self.parentViewController;
    while (maybe && ![maybe isKindOfClass:[AwfulExpandingSplitViewController class]]) {
        maybe = maybe.parentViewController;
    }
    return (AwfulExpandingSplitViewController *)maybe;
}

@end
