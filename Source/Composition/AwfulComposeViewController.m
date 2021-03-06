//  AwfulComposeViewController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulComposeViewControllerSubclass.h"
#import "AwfulAlertView.h"
#import "AwfulKeyboardBar.h"
#import "ImgurHTTPClient.h"

@interface AwfulComposeViewController () <UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIPopoverControllerDelegate, UIViewControllerRestoration>

@property (nonatomic) AwfulTextView *textView;
@property (nonatomic) AwfulKeyboardBar *bbcodeBar;

@property (weak, nonatomic) id <ImgurHTTPClientCancelToken> imageUploadCancelToken;
@property (nonatomic) UIPopoverController *pickerPopover;

@property (nonatomic) BOOL viewIsDisappearing;

@end


@implementation AwfulComposeViewController

- (AwfulTextView *)textView
{
    if (_textView) return _textView;
    _textView = [AwfulTextView new];
    _textView.delegate = self;
    _textView.frame = (CGRect){ .size = self.view.bounds.size };
    _textView.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
                                  UIViewAutoresizingFlexibleHeight);
    _textView.font = [UIFont systemFontOfSize:17];
    _textView.keyboardAppearance = UIKeyboardAppearanceAlert;
    _textView.tintColor = [UIColor colorWithRed:0.118 green:0.518 blue:0.686 alpha:1];
    return _textView;
}

- (AwfulKeyboardBar *)bbcodeBar
{
    if (_bbcodeBar) return _bbcodeBar;
    _bbcodeBar = [AwfulKeyboardBar new];
    _bbcodeBar.frame = CGRectMake(0, 0, CGRectGetWidth(_textView.bounds),
                                 UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? 63 : 36);
    _bbcodeBar.characters = @[ @"[", @"=", @":", @"/", @"]" ];
    return _bbcodeBar;
}

- (UIBarButtonItem *)sendButton
{
    if (_sendButton) return _sendButton;
    _sendButton = [[UIBarButtonItem alloc] initWithTitle:@"Send" style:UIBarButtonItemStyleDone
                                                  target:nil action:NULL];
    return _sendButton;
}

- (UIBarButtonItem *)cancelButton
{
    if (_cancelButton) return _cancelButton;
    _cancelButton = [[UIBarButtonItem alloc] initWithTitle:@"Cancel"
                                                     style:UIBarButtonItemStyleBordered
                                                    target:nil action:NULL];
    return _cancelButton;
}

- (void)prepareToSendMessage
{
    NSArray *imagePlaceholderResults = ImagePlaceholderResultsWithMessageBody(self.textView.text);
    if ([imagePlaceholderResults count] > 0) {
        NSMutableArray *imageKeys = [NSMutableArray new];
        for (NSTextCheckingResult *result in imagePlaceholderResults) {
            NSRange range = [result rangeAtIndex:3];
            if (range.location == NSNotFound) continue;
            [imageKeys addObject:[self.textView.text substringWithRange:range]];
        }
        NSMutableArray *images = [[self.images objectsForKeys:imageKeys
                                               notFoundMarker:[NSNull null]] mutableCopy];
        [images removeObject:[NSNull null]];
        if ([images count] > 0) {
            [self willTransitionToState:AwfulComposeViewControllerStateUploadingImages];
            self.state = AwfulComposeViewControllerStateUploadingImages;
            id token = [[ImgurHTTPClient client] uploadImages:images
                                                      andThen:^(NSError *error, NSArray *urls)
            {
                if (error) {
                    [self willTransitionToState:AwfulComposeViewControllerStateError];
                    self.state = AwfulComposeViewControllerStateError;
                    [AwfulAlertView showWithTitle:@"Image Uploading Failed" error:error
                                      buttonTitle:@"OK" completion:^
                    {
                        [self willTransitionToState:AwfulComposeViewControllerStateReady];
                        self.state = AwfulComposeViewControllerStateReady;
                    }];
                    return;
                }
                NSDictionary *imgurURLs = [NSDictionary dictionaryWithObjects:urls
                                                                      forKeys:imageKeys];
                [self replaceImagePlaceholdersInMessageBody:self.textView.text
                                          atRangesInResults:imagePlaceholderResults
                                                   withURLs:imgurURLs];
            }];
            self.imageUploadCancelToken = token;
            return;
        }
    }
    [self replaceImagePlaceholdersInMessageBody:self.textView.text
                              atRangesInResults:imagePlaceholderResults
                                       withURLs:nil];
}

static NSArray * ImagePlaceholderResultsWithMessageBody(NSString *messageBody)
{
    NSString *pattern = @"\\[(t?img)\\](imgur://(.+)\\.png)\\[/\\1\\]";
    NSError *error;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                           options:0
                                                                             error:&error];
    if (!regex) {
        NSLog(@"error parsing image URL placeholder regex: %@", error);
        return nil;
    }
    return [regex matchesInString:messageBody options:0 range:NSMakeRange(0, [messageBody length])];
}

- (void)replaceImagePlaceholdersInMessageBody:(NSString *)messageBody
                            atRangesInResults:(NSArray *)results
                                     withURLs:(NSDictionary *)urls
{
    [self willTransitionToState:AwfulComposeViewControllerStateSending];
    self.state = AwfulComposeViewControllerStateSending;
    NSMutableString *replacedBody = [messageBody mutableCopy];
    NSInteger offset = 0;
    for (__strong NSTextCheckingResult *result in results) {
        result = [result resultByAdjustingRangesWithOffset:offset];
        NSRange keyRange = [result rangeAtIndex:3];
        if (keyRange.location == NSNotFound) continue;
        NSString *key = [replacedBody substringWithRange:keyRange];
        NSString *url = [urls[key] absoluteString];
        NSUInteger priorLength = [replacedBody length];
        if (url) {
            [replacedBody replaceCharactersInRange:[result rangeAtIndex:2] withString:url];
        } else {
            NSLog(@"missing associated image URL for tag %@",
                  [replacedBody substringWithRange:result.range]);
            [replacedBody replaceCharactersInRange:result.range withString:@""];
        }
        offset += ([replacedBody length] - priorLength);
    }
    [self send:replacedBody];
}

- (void)send:(NSString *)messageBody
{
    [self doesNotRecognizeSelector:_cmd];
}

- (void)cancel
{
    [self.imageUploadCancelToken cancel];
    if (self.state != AwfulComposeViewControllerStateReady) {
        [self willTransitionToState:AwfulComposeViewControllerStateReady];
        self.state = AwfulComposeViewControllerStateReady;
    }
}

- (void)willTransitionToState:(AwfulComposeViewControllerState)state
{
    // noop; subclasses are free to implement
}

#pragma mark - UIViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (!(self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) return nil;
    _images = [NSMutableDictionary new];
    self.restorationClass = self.class;
    self.navigationItem.rightBarButtonItem = self.sendButton;
    self.navigationItem.leftBarButtonItem = self.cancelButton;
    self.modalPresentationStyle = UIModalPresentationPageSheet;
    return self;
}

- (void)loadView
{
    self.view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame];
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.textView];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification object:nil];
    [self willTransitionToState:AwfulComposeViewControllerStateReady];
    self.state = AwfulComposeViewControllerStateReady;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    self.viewIsDisappearing = YES;
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification
                                                  object:nil];
    self.viewIsDisappearing = NO;
}

- (void)keyboardWillShow:(NSNotification *)note
{
    CGRect keyboardFrame = [note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    keyboardFrame = [self.view.window convertRect:keyboardFrame fromWindow:nil];
    CGRect relativeKeyboardFrame = [self.textView.superview convertRect:keyboardFrame fromView:nil];
    CGRect textViewFrame = self.textView.frame;
    textViewFrame.size.height += CGRectGetMinY(relativeKeyboardFrame) - CGRectGetMaxY(textViewFrame);
    [self animateWithKeyboardUserInfo:note.userInfo animations:^{
        self.textView.frame = textViewFrame;
    } completion:^(BOOL finished) {
        [self.textView scrollRangeToVisible:self.textView.selectedRange];
    }];
}

- (void)keyboardWillHide:(NSNotification *)note
{
    if (self.viewIsDisappearing) return;
    [self animateWithKeyboardUserInfo:note.userInfo animations:^{
        self.textView.frame = (CGRect){ .size = self.view.bounds.size };
    } completion:^(BOOL finished) {
        [self.textView scrollRangeToVisible:self.textView.selectedRange];
    }];
}

- (void)animateWithKeyboardUserInfo:(NSDictionary *)userInfo
                         animations:(void (^)(void))animations
                         completion:(void (^)(BOOL finished))completion
{
    UIViewAnimationCurve curve = [userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];
    // TODO this animation is busted on iOS 7. It just bounces continuously behind the keyboard.
    [UIView animateWithDuration:0
                          delay:0
                        options:AnimationOptionsWithAnimationCurve(curve)
                     animations:animations
                     completion:completion];
}

static UIViewAnimationOptions AnimationOptionsWithAnimationCurve(UIViewAnimationCurve curve)
{
    switch (curve) {
        case UIViewAnimationCurveEaseInOut: return UIViewAnimationOptionCurveEaseInOut;
        case UIViewAnimationCurveEaseIn: return UIViewAnimationOptionCurveEaseIn;
        case UIViewAnimationCurveEaseOut: return UIViewAnimationOptionCurveEaseOut;
        case UIViewAnimationCurveLinear: return UIViewAnimationOptionCurveLinear;
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) return YES;
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - AwfulTextViewDelegate

- (BOOL)textViewShouldBeginEditing:(UITextView *)textView
{
    self.bbcodeBar.keyInputView = _textView;
    self.textView.inputAccessoryView = self.bbcodeBar;
    return YES;
}

- (void)textView:(AwfulTextView *)textView
showImagePickerForSourceType:(UIImagePickerControllerSourceType)sourceType
{
    if (![UIImagePickerController isSourceTypeAvailable:sourceType]) return;
    NSArray *available = [UIImagePickerController availableMediaTypesForSourceType:sourceType];
    if (![available containsObject:(NSString *)kUTTypeImage]) return;
    UIImagePickerController *picker = [UIImagePickerController new];
    picker.sourceType = sourceType;
    picker.mediaTypes = @[ (NSString *)kUTTypeImage ];
    picker.allowsEditing = NO;
    picker.delegate = self;
    BOOL iPad = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
    if (iPad && sourceType == UIImagePickerControllerSourceTypePhotoLibrary) {
        self.pickerPopover = [[UIPopoverController alloc] initWithContentViewController:picker];
        self.pickerPopover.delegate = self;
        [self.pickerPopover presentPopoverFromRect:[self.textView selectedTextRect]
                                            inView:self.textView
                          permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
    } else {
        [self presentViewController:picker animated:YES completion:nil];
    }
}

- (void)textView:(AwfulTextView *)textView insertImage:(UIImage *)image
{
    [self saveImageAndInsertPlaceholder:image];
}

- (void)saveImageAndInsertPlaceholder:(UIImage *)image
{
    NSNumberFormatterStyle numberStyle = NSNumberFormatterSpellOutStyle;
    NSString *key = [NSNumberFormatter localizedStringFromNumber:@([self.images count] + 1)
                                                     numberStyle:numberStyle];
    // TODO when we implement reloading state after termination, save images to Caches folder.
    self.images[key] = image;
    
    // "Keep all images smaller than **800 pixels horizontal and 600 pixels vertical.**"
    // http://www.somethingawful.com/d/forum-rules/forum-rules.php?page=2
    BOOL shouldThumbnail = image.size.width > 800 || image.size.height > 600;
    [self.textView replaceRange:self.textView.selectedTextRange
                       withText:ImageKeyToPlaceholder(key, shouldThumbnail)];
}

static NSString *ImageKeyToPlaceholder(NSString *key, BOOL thumbnail)
{
    NSString *t = thumbnail ? @"t" : @"";
    return [NSString stringWithFormat:@"[%@img]imgur://%@.png[/%@img]", t, key, t];
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker
didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    if ([info[UIImagePickerControllerMediaType] isEqual:(NSString *)kUTTypeImage]) {
        UIImage *image = info[UIImagePickerControllerEditedImage];
        if (!image) image = info[UIImagePickerControllerOriginalImage];
        [self saveImageAndInsertPlaceholder:image];
    }
    if (self.pickerPopover) {
        [self.pickerPopover dismissPopoverAnimated:YES];
        self.pickerPopover = nil;
    } else {
        [picker dismissViewControllerAnimated:YES completion:nil];
    }
    [self.textView becomeFirstResponder];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    // This seemingly never gets called when the picker is in a popover, so we can just blindly
    // dismiss the picker.
    [self dismissViewControllerAnimated:YES completion:nil];
    [self.textView becomeFirstResponder];
}

#pragma mark - UINavigationControllerDelegate

// Set the title of the topmost view of the UIImagePickerController.
- (void)navigationController:(UINavigationController *)navigationController
      willShowViewController:(UIViewController *)viewController
                    animated:(BOOL)animated
{
    if ([navigationController.viewControllers count] == 1) {
        viewController.navigationItem.title = @"Insert Image";
    }
}

#pragma mark - UIPopoverControllerDelegate

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
    if (![popoverController isEqual:self.pickerPopover]) return;
    [self.textView becomeFirstResponder];
}

#pragma mark State preservation and restoration

+ (UIViewController *)viewControllerWithRestorationIdentifierPath:(NSArray *)identifierComponents coder:(NSCoder *)coder
{
    AwfulComposeViewController *composeView = [self new];
    composeView.restorationIdentifier = identifierComponents.lastObject;
    return composeView;
}

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super encodeRestorableStateWithCoder:coder];
    [coder encodeObject:self.textView.attributedText forKey:TextKey];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super decodeRestorableStateWithCoder:coder];
    self.textView.attributedText = [coder decodeObjectForKey:TextKey];
}

static NSString * const TextKey = @"AwfulText";

@end
