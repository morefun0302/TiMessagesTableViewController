//
//  TiMessagesTableViewController.m
//  TiMessagesTableViewController
//
//  Created by Arai Hiroki on 2014/04/13.
//
//

#import "TiMessagesTableViewController.h"
#import "TiMessage.h"
#import "TiBubbleImagesViewFactory.h"
#import "ComArihiroMessagestableModule.h"
#import "ComArihiroMessagestableViewProxy.h"

ComArihiroMessagestableModule *proxy;

@implementation TiMessagesTableViewController

@synthesize proxy;
@synthesize messages;
@synthesize incomingColor;
@synthesize incomingBubbleColor;
@synthesize outgoingColor;
@synthesize outgoingBubbleColor;
@synthesize failedBubbleColor;
@synthesize senderColor;
@synthesize senderFont;
@synthesize timestampColor;
@synthesize timestampFont;
@synthesize failedAlert;

CGRect originalTableViewFrame;
BOOL isVisible;

#pragma mark lifecycle

- (void)viewDidLoad
{
    self.delegate = self;
    self.dataSource = self;
    
    // initialize properties
    messages = [[NSMutableArray alloc] init];
    incomingBubbleColor = [UIColor js_bubbleBlueColor];
    outgoingBubbleColor = [UIColor js_bubbleLightGrayColor];
    failedBubbleColor = [UIColor redColor];
    senderColor = [UIColor lightGrayColor];
    timestampColor = [UIColor lightGrayColor];
    failedAlert = @"failed to send.";


    [super viewDidLoad];

    self.messageInputView.image = [[[ComArihiroMessagestableModule getShared] getAssetImage:@"input-bar-flat.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(2.0f, 0.0f, 0.0f, 0.0f)
                                                                                                                                  resizingMode:UIImageResizingModeStretch];

    [self setBackgroundColor:[UIColor whiteColor]];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFastForward
                                                                                           target:self
                                                                                           action:@selector(buttonPressed:)];

    for (UIGestureRecognizer *recognizer in [self.tableView gestureRecognizers]) {
        if ([recognizer isKindOfClass:[UITapGestureRecognizer class]]) {
            [recognizer addTarget:self action:@selector(handleTapGesture:)];
        }
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    if (isVisible) {
        return;
    }
    [super viewWillAppear:animated];
    [self scrollToBottomAnimated:NO];

    NSDictionary *eventObj = [[NSDictionary alloc] initWithObjectsAndKeys:
                              self.sender, @"sender",
                              nil];
    [proxy fireEvent:@"opened" withObject:eventObj];
    isVisible = YES;
    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    if (!isVisible) {
        return;
    }
    [super viewWillDisappear:animated];
    NSDictionary *eventObj = [[NSDictionary alloc] initWithObjectsAndKeys:
                              self.sender, @"sender",
                              nil];
    [proxy fireEvent:@"closed" withObject:eventObj];
    isVisible = NO;
    [super viewWillDisappear:animated];
}

#pragma mark Handle gesture

- (void)handleTapGesture:(UIPanGestureRecognizer *)tap
{
    NSDictionary *eventObj = [[NSDictionary alloc] initWithObjectsAndKeys:
                              @"tableView", @"target",
                              nil];
    [proxy fireEvent:@"click" withObject:eventObj];
}

- (void)handleTapBubble:(UITapGestureRecognizer *)tap
{
    UIView *cell = tap.view;
    while (cell != nil && ![cell isKindOfClass:[UITableViewCell class]]) {
        cell = [cell superview];
    }
    NSIndexPath *indexPath = [self.tableView indexPathForCell:(UITableViewCell *)cell];
    TiMessage *message = nil;
    if ([messages count] > indexPath.row) {
        message = [messages objectAtIndex:indexPath.row];
    }
    if (message == nil) {
        return;
    }
    NSDictionary *eventObj = [message eventObject];
    [eventObj setValue:@"message" forKey:@"target"];
    [eventObj setValue:[NSNumber numberWithUnsignedInteger:indexPath.row] forKey:@"index"];
    [proxy fireEvent:@"click" withObject:eventObj];
}

#pragma mark Public

- (TiMessage *)getMessageWithMessageId:(NSInteger)messageId
{
    TiMessage* message = nil;
    for (TiMessage *msg in messages) {
        if (msg.messageId == messageId) {
            message = msg;
        }
    }
    return message;
}

- (TiMessage *)addMessage:(NSString *)text sender:(NSString *)sender date:(NSDate *)date status:(MSG_STATUS_ENUM)status
{
    TiMessage* message = [[TiMessage alloc] initWithText:text sender:sender date:date status:status];
    [messages addObject:message];
    [self.tableView reloadData];
    [self scrollToBottomAnimated:YES];
    return message;
}
- (NSUInteger)removeMessageWithMessageID:(NSUInteger)messageId
{
    TiMessage* message = [self getMessageWithMessageId:messageId];
    if (message == nil) {
        return;
    }
    NSUInteger index = [messages indexOfObject:message];
    [messages removeObject:message];

    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
    [self.tableView beginUpdates];
    [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
    [self.tableView endUpdates];

    NSMutableDictionary *eventObj = [message eventObject];
    [proxy fireEvent:@"removed" withObject:eventObj];

    return index;
}


- (BOOL)succeedInSendingMessageWithMessageID:(NSInteger)messageId
{
    TiMessage* message = [self getMessageWithMessageId:messageId];
    if (message == nil) {
        return NO;
    }
    message.status = MSG_SUCCESS;
    [self.tableView reloadData];
    return YES;
}
- (BOOL)failInSendingMessageWithMessageID:(NSInteger)messageId
{
    TiMessage* message = [self getMessageWithMessageId:messageId];
    if (message == nil) {
        return NO;
    }
    message.status = MSG_FAILED;
    [self.tableView reloadData];

    return YES;
}

- (BOOL)hideMessageInputView
{
    if ([self.messageInputView isHidden]) {
        return NO;
    }
    [self.messageInputView.textView resignFirstResponder];

    CGFloat height = self.messageInputView.frame.size.height;
    originalTableViewFrame = self.tableView.frame;

    CGRect newFrame = self.tableView.frame;
    newFrame.size.height = originalTableViewFrame.size.height + height;
    [self.tableView setFrame:newFrame];

    [self.messageInputView setHidden:YES];
    [self scrollToBottomAnimated:YES];
    
    [proxy fireEvent:@"hideinput"];

    return YES;
}
- (BOOL)showMessageInputView
{
    if (![self.messageInputView isHidden]) {
        return NO;
    }
    [self.tableView setFrame:originalTableViewFrame];

    [self.messageInputView.textView becomeFirstResponder];

    [self.messageInputView setHidden:NO];
    [self scrollToBottomAnimated:YES];

    [proxy fireEvent:@"showinput"];

    return YES;
}

- (void)setSendButtonTitle:(NSString *)title
{
    [self.messageInputView.sendButton setTitle:title forState:UIControlStateNormal];
    [self.messageInputView.sendButton setTitle:title forState:UIControlStateHighlighted];
    [self.messageInputView.sendButton setTitle:title forState:UIControlStateDisabled];
}

- (BOOL)becomeFirstResponder
{
    return [self.messageInputView.textView becomeFirstResponder];
}
- (BOOL)resignFirstResponder
{
    return [self.messageInputView.textView resignFirstResponder];
}


#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.messages.count;
}


#pragma mark - JSMessagesViewDelegate protocol
#pragma mark required


/**
 *  Tells the delegate that the user has sent a message with the specified text, sender, and date.
 *
 *  @param text   The text that was present in the textView of the messageInputView when the send button was pressed.
 *  @param sender The user who sent the message.
 *  @param date   The date and time at which the message was sent.
 */
- (void)didSendText:(NSString *)text fromSender:(NSString *)sender onDate:(NSDate *)date {
    TiMessage *message = [self addMessage:text sender:sender date:date status:MSG_PENDING];
    [self finishSend];

    
    NSMutableDictionary *eventObj = [message eventObject];
    [eventObj setValue:[NSNumber numberWithUnsignedInteger:[messages indexOfObject:message]] forKey:@"index"];
    [proxy fireEvent:@"send" withObject:eventObj];
}

/**
 *  Asks the delegate for the message type for the row at the specified index path.
 *
 *  @param indexPath The index path of the row to be displayed.
 *
 *  @return A constant describing the message type.
 *  @see JSBubbleMessageType.
 */
- (JSBubbleMessageType)messageTypeForRowAtIndexPath:(NSIndexPath *)indexPath {
    TiMessage *message = [messages objectAtIndex:indexPath.row];
    return [message.sender isEqualToString:self.sender] ? JSBubbleMessageTypeOutgoing : JSBubbleMessageTypeIncoming;
}

/**
 *  Asks the delegate for the bubble image view for the row at the specified index path with the specified type.
 *
 *  @param type      The type of message for the row located at indexPath.
 *  @param indexPath The index path of the row to be displayed.
 *
 *  @return A `UIImageView` with both `image` and `highlightedImage` properties set.
 *  @see JSBubbleImageViewFactory.
 */
- (UIImageView *)bubbleImageViewWithType:(JSBubbleMessageType)type forRowAtIndexPath:(NSIndexPath *)indexPath {
    TiMessage *message = [messages objectAtIndex:indexPath.row];
    if (message.status == MSG_FAILED) {
        return [TiBubbleImagesViewFactory bubbleImageViewForType:type color:failedBubbleColor];
    }
    UIColor *color = type == JSBubbleMessageTypeOutgoing ? outgoingBubbleColor : incomingBubbleColor;
    return [TiBubbleImagesViewFactory bubbleImageViewForType:type color:color];
}

/**
 *  Asks the delegate for the input view style.
 *
 *  @return A constant describing the input view style.
 *  @see JSMessageInputViewStyle.
 */
- (JSMessageInputViewStyle)inputViewStyle {
    return JSMessageInputViewStyleFlat;
}

#pragma mark optional

/**
 *  Asks the delegate if a timestamp should be displayed *above* the row at the specified index path.
 *
 *  @param indexPath The index path of the row to be displayed.
 *
 *  @return A boolean value specifying whether or not a timestamp should be displayed for the row at indexPath. The default value is `YES`.
 */
// - (BOOL)shouldDisplayTimestampForRowAtIndexPath:(NSIndexPath *)indexPath {}

/**
 *  Asks the delegate to configure or further customize the given cell at the specified index path.
 *
 *  @param cell      The message cell to configure.
 *  @param indexPath The index path for cell.
 */
- (void)configureCell:(JSBubbleMessageCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    cell.bubbleView.textView.textColor = [cell messageType] == JSBubbleMessageTypeOutgoing ? outgoingColor : incomingColor;

    TiMessage *message = [messages objectAtIndex:indexPath.row];

    if ([cell messageType] == JSBubbleMessageTypeOutgoing) {
        cell.bubbleView.alpha = message.status == MSG_PENDING ? 0.6 : 1;
        UIImageView *bubbleImageView = [self bubbleImageViewWithType:[self messageTypeForRowAtIndexPath:indexPath]
                                                   forRowAtIndexPath:indexPath];
        cell.bubbleView.bubbleImageView.image = bubbleImageView.image;

        if ([cell.bubbleView.textView respondsToSelector:@selector(linkTextAttributes)]) {
            NSMutableDictionary *attrs = [cell.bubbleView.textView.linkTextAttributes mutableCopy];
            [attrs setValue:[UIColor blueColor] forKey:NSForegroundColorAttributeName];

            cell.bubbleView.textView.linkTextAttributes = attrs;
        }
    }

    if (cell.timestampLabel) {
        if (timestampFont != nil) {
            cell.timestampLabel.font = timestampFont;
        }

        cell.timestampLabel.textColor = timestampColor;
        cell.timestampLabel.shadowOffset = CGSizeZero;
        cell.timestampLabel.textAlignment = [cell messageType] == JSBubbleMessageTypeOutgoing ? NSTextAlignmentRight : NSTextAlignmentLeft;
        NSDate *timestamp = ((TiMessage *)[messages objectAtIndex:indexPath.row]).date;
        if (message.status == MSG_FAILED) {
            cell.timestampLabel.text = failedAlert;
        } else {
            cell.timestampLabel.text = [NSDateFormatter localizedStringFromDate:timestamp
                                                                      dateStyle:NSDateFormatterNoStyle
                                                                      timeStyle:NSDateFormatterShortStyle];
        }
    }
    
    if (cell.subtitleLabel) {
        if (senderFont != nil) {
            cell.subtitleLabel.font = senderFont;
        }
        cell.subtitleLabel.textColor = senderColor;
    }
    BOOL isRegisterd = NO;
    for (UIGestureRecognizer *recognizer in [cell.bubbleView gestureRecognizers]) {
        if ([recognizer isKindOfClass:[UITapGestureRecognizer class]]) {
            isRegisterd = YES;
        }
    }
    if (!isRegisterd) {
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapBubble:)];
        [cell.bubbleView addGestureRecognizer:tap];
        [tap addTarget:self action:@selector(handleTapGestureRecognizer:)];
    }

    
#if TARGET_IPHONE_SIMULATOR
    cell.bubbleView.textView.dataDetectorTypes = UIDataDetectorTypeNone;
#else
    cell.bubbleView.textView.dataDetectorTypes = UIDataDetectorTypeAll;
#endif
}


/**
 *  Asks the delegate if should always scroll to bottom automatically when new messages are sent or received.
 *
 *  @return `YES` if you would like to prevent the table view from being scrolled to the bottom while the user is scrolling the table view manually, `NO` otherwise.
 */
- (BOOL)shouldPreventScrollToBottomWhileUserScrolling
{
    return YES;
}

/**
 *  Ask the delegate if the keyboard should be dismissed by panning/swiping downward. The default value is `YES`. Return `NO` to dismiss the keyboard by tapping.
 *
 *  @return A boolean value specifying whether the keyboard should be dismissed by panning/swiping.
 */
- (BOOL)allowsPanToDismissKeyboard
{
    return NO;
}

/**
 *  Asks the delegate for the send button to be used in messageInputView. Implement this method if you wish to use a custom send button. The button must be a `UIButton` or a subclass of `UIButton`. The button's frame is set for you.
 *
 *  @return A custom `UIButton` to use in messageInputView.
 */
// - (UIButton *)sendButtonForInputView {}

/**
 *  Asks the delegate for a custom cell reuse identifier for the row to be displayed at the specified index path.
 *
 *  @param indexPath The index path of the row to be displayed.
 *
 *  @return A string specifying the cell reuse identifier for the row at indexPath.
 */
// - (NSString *)customCellIdentifierForRowAtIndexPath:(NSIndexPath *)indexPath {}


#pragma mark - JSMessagesViewDataSource
#pragma mark required
/**
 *  Asks the data source for the message object to display for the row at the specified index path. The message text is displayed in the bubble at index path. The message date is displayed *above* the row at the specified index path. The message sender is displayed *below* the row at the specified index path.
 *
 *  @param indexPath An index path locating a row in the table view.
 *
 *  @return An object that conforms to the `JSMessageData` protocol containing the message data. This value must not be `nil`.
 */
- (id<JSMessageData>)messageForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [self.messages objectAtIndex:indexPath.row];
}

/**
 *  Asks the data source for the imageView to display for the row at the specified index path with the given sender. The imageView must have its `image` property set.
 *
 *  @param indexPath An index path locating a row in the table view.
 *  @param sender    The name of the user who sent the message at indexPath.
 *
 *  @return An image view specifying the avatar for the message at indexPath. This value may be `nil`.
 */
- (UIImageView *)avatarImageViewForRowAtIndexPath:(NSIndexPath *)indexPath sender:(NSString *)sender {
    return nil;
}


@end
