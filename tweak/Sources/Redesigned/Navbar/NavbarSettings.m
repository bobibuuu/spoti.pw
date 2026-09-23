#import "Core/SGCore.h"
#import "Settings/SGPage.h"
#import "Settings/SGPageStyle.h"
#import "Navbar.h"
#import "Shared/Navigation/Links.h"
#import "Headers/SPTEncoreIconView.h"
#import <objc/message.h>
#import <objc/runtime.h>
#import <stdlib.h>

// What "Add a tab" offers: URIs Spotify's own router resolves to a page of its own, each with the
// name of the SPTEncoreIcon class method that draws its glyph. Playlists was spotify:collection:playlists
// until 0.20, which 9.1.78 knows only from its old iPad sidebar table and has no handler for (#66);
// spotify:playlists is the form its collection URI parser lists, next to spotify:playlists:by-you.
// The picker still asks the dispatcher about each one and leaves out what it has nowhere to send.
static NSArray<NSDictionary *> *tabPresets(void) {
    return @[
        @{SGRNavbarTitle: @"Home", SGRNavbarURI: @"spotify:home", SGRNavbarIcon: @"home"},
        @{SGRNavbarTitle: @"Search", SGRNavbarURI: @"spotify:search", SGRNavbarIcon: @"search"},
        @{SGRNavbarTitle: @"Your Library", SGRNavbarURI: @"spotify:collection", SGRNavbarIcon: @"collection"},
        @{SGRNavbarTitle: @"Liked Songs", SGRNavbarURI: @"spotify:collection:tracks", SGRNavbarIcon: @"heart"},
        @{SGRNavbarTitle: @"Playlists", SGRNavbarURI: @"spotify:playlists", SGRNavbarIcon: @"playlist"},
        @{SGRNavbarTitle: @"Albums", SGRNavbarURI: @"spotify:collection:albums", SGRNavbarIcon: @"album"},
        @{SGRNavbarTitle: @"Artists", SGRNavbarURI: @"spotify:collection:artists", SGRNavbarIcon: @"artist"},
        @{SGRNavbarTitle: @"Podcasts", SGRNavbarURI: @"spotify:collection:podcasts", SGRNavbarIcon: @"podcasts"},
        @{SGRNavbarTitle: @"Audiobooks", SGRNavbarURI: @"spotify:collection:audiobooks", SGRNavbarIcon: @"audiobook"},
        @{SGRNavbarTitle: @"Downloads", SGRNavbarURI: @"spotify:collection:downloads", SGRNavbarIcon: @"downloaded"},
        @{SGRNavbarTitle: @"Your Episodes", SGRNavbarURI: @"spotify:collection:your-episodes", SGRNavbarIcon: @"bookmark"},
        @{SGRNavbarTitle: @"Browse", SGRNavbarURI: @"spotify:browse", SGRNavbarIcon: @"browse"},
        @{SGRNavbarTitle: @"New Releases", SGRNavbarURI: @"spotify:new-releases", SGRNavbarIcon: @"star"},
        @{SGRNavbarTitle: @"Made For You", SGRNavbarURI: @"spotify:made-for-you", SGRNavbarIcon: @"user"},
        @{SGRNavbarTitle: @"Concerts", SGRNavbarURI: @"spotify:concerts", SGRNavbarIcon: @"events"},
        @{SGRNavbarTitle: @"Queue", SGRNavbarURI: @"spotify:now-playing:queue", SGRNavbarIcon: @"queue"},
        @{SGRNavbarTitle: @"Create", SGRNavbarURI: @"spotify:create-menu", SGRNavbarIcon: @"plus"},
    ];
}

// The list the Navbar page edits: the saved order first, then every tab of Spotify's it does not
// name, in Spotify's order. Entries for tabs Spotify no longer has drop out.
static NSMutableArray<NSMutableDictionary *> *navbarEntries(void) {
    NSArray<NSString *> *stock = SGRNavbarStock();
    NSMutableArray<NSMutableDictionary *> *entries = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    for (NSDictionary *entry in SGRNavbarLayout()) {
        NSString *ident = entry[SGRNavbarID];
        if (![ident isKindOfClass:NSString.class] || [seen containsObject:ident]) continue;
        if (!entry[SGRNavbarURI] && ![stock containsObject:ident]) continue;
        [seen addObject:ident];
        [entries addObject:[entry mutableCopy]];
    }
    for (NSString *ident in stock) {
        if ([seen containsObject:ident]) continue;
        [entries addObject:[@{SGRNavbarID: ident, SGRNavbarTitle: ident} mutableCopy]];
    }
    return entries;
}

// A tab of the mod's own carries an identity of its own, so the same page can sit on the bar twice
// and renaming one does not shuffle the order.
static void appendTab(NSDictionary *tab) {
    NSMutableDictionary *entry = [tab mutableCopy];
    entry[SGRNavbarID] = NSUUID.UUID.UUIDString;
    SGRSetNavbarLayout([navbarEntries() arrayByAddingObject:entry]);
    SGRRefreshTabBar();
}

static NSString *const SGRTabDraftIconChosen = @"iconChosen";

static UIView *SGRTabIconPreview(NSString *name, CGFloat size) {
    if ([name hasPrefix:@"sf:"]) {
        NSString *symbol = [name substringFromIndex:3];
        UIImage *image = [UIImage systemImageNamed:symbol withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightMedium]];
        UIImageView *preview = [[UIImageView alloc] initWithImage:image];
        preview.tintColor = UIColor.whiteColor;
        preview.contentMode = UIViewContentModeScaleAspectFit;
        preview.frame = CGRectMake(0, 0, size, size);
        return preview;
    }
    Class iconClass = NSClassFromString(@"SPTEncoreIcon");
    Class viewClass = NSClassFromString(@"SPTEncoreIconView");
    SEL selector = NSSelectorFromString(name.length ? name : @"star");
    if (iconClass && viewClass && [iconClass respondsToSelector:selector]) {
        id (*iconFor)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
        id icon = iconFor(iconClass, selector);
        SPTEncoreIconView *preview = icon ? [[viewClass alloc] initWithIcon:icon] : nil;
        if (preview) {
            preview.frame = CGRectMake(0, 0, size, size);
            [preview setForegroundColor:UIColor.whiteColor];
            [preview setIsActive:NO];
            return preview;
        }
    }
    UIImageView *fallback = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"star.fill"]];
    fallback.tintColor = UIColor.whiteColor;
    fallback.frame = CGRectMake(0, 0, size, size);
    return fallback;
}

static NSString *SGRTabIconDescription(NSString *name) {
    if ([name hasPrefix:@"sf:"]) return [NSString stringWithFormat:@"SF Symbols · %@", [name substringFromIndex:3]];
    return [NSString stringWithFormat:@"Spotify Encore · %@", name.length ? name : @"star"];
}

static UIView *SGRTabIconAccessory(NSString *name) {
    UIView *accessory = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 52, 28)];
    UIView *preview = SGRTabIconPreview(name, 24);
    preview.frame = CGRectMake(0, 2, 24, 24);
    [accessory addSubview:preview];
    UIImageView *chevron = SGSymbolView(@"chevron.right", 12, UIImageSymbolWeightRegular, 16);
    chevron.tintColor = SGGrey();
    chevron.frame = CGRectMake(34, 6, 16, 16);
    [accessory addSubview:chevron];
    return accessory;
}

static NSArray<NSDictionary *> *openablePresets(void) {
    NSMutableArray<NSDictionary *> *kept = [NSMutableArray array];
    for (NSDictionary *tab in tabPresets()) {
        NSString *via = nil;
        SGLinkRoute route = SGSpotifyURIRoute([NSURL URLWithString:tab[SGRNavbarURI]], &via);
        SGLog(@"navbar: preset %@ -> %@", tab[SGRNavbarURI],
              route == SGLinkRouteOpens ? via : route == SGLinkRouteNone ? @"no handler, left out" : @"unknown");
        if (route != SGLinkRouteNone) [kept addObject:tab];
    }
    return kept;
}

@interface SGRTabLinkPickerPage : SGPage
- (instancetype)initWithDraft:(NSMutableDictionary *)draft;
- (void)showLinkError:(NSString *)message;
@end

@interface SGRTabIconPickerPage : SGPage
- (instancetype)initWithDraft:(NSMutableDictionary *)draft;
@end

@interface SGRTabEditorPage : SGPage <UITextFieldDelegate>
- (instancetype)initWithDraft:(NSMutableDictionary *)draft;
@end

@implementation SGRTabEditorPage {
    NSMutableDictionary *_draft;
    UITextField *_nameField;
}

- (instancetype)initWithDraft:(NSMutableDictionary *)draft {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    _draft = draft;
    self.title = @"Add a Tab";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Add" style:UIBarButtonItemStyleDone target:self action:@selector(add)];
    self.navigationItem.rightBarButtonItem.enabled = [_draft[SGRNavbarURI] length] > 0;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)table { return 2; }
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section { return section == 0 ? 1 : 2; }
- (UIView *)tableView:(UITableView *)table viewForHeaderInSection:(NSInteger)section {
    return SGSectionHeader(table, section == 0 ? @"Name" : @"Customize");
}
- (CGFloat)tableView:(UITableView *)table heightForHeaderInSection:(NSInteger)section { return SGSectionHeaderHeight; }
- (CGFloat)tableView:(UITableView *)table heightForFooterInSection:(NSInteger)section { return CGFLOAT_MIN; }
- (CGFloat)tableView:(UITableView *)table heightForRowAtIndexPath:(NSIndexPath *)path { return path.section == 0 ? 56 : UITableViewAutomaticDimension; }

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    if (path.section == 0) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.backgroundColor = SGCardBackground();
        UITextField *field = [UITextField new];
        field.translatesAutoresizingMaskIntoConstraints = NO;
        field.textColor = UIColor.whiteColor;
        field.tintColor = SGGreen();
        field.placeholder = @"Name";
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.returnKeyType = UIReturnKeyDone;
        field.delegate = self;
        field.text = _draft[SGRNavbarTitle];
        [field addTarget:self action:@selector(nameChanged:) forControlEvents:UIControlEventEditingChanged];
        [cell.contentView addSubview:field];
        [NSLayoutConstraint activateConstraints:@[
            [field.leadingAnchor constraintEqualToAnchor:cell.contentView.layoutMarginsGuide.leadingAnchor],
            [field.trailingAnchor constraintEqualToAnchor:cell.contentView.layoutMarginsGuide.trailingAnchor],
            [field.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
        ]];
        _nameField = field;
        return cell;
    }
    UITableViewCell *cell = SGDequeueCell(table, @"tab-editor");
    if (path.row == 0) {
        NSString *uri = _draft[SGRNavbarURI];
        SGFillCell(cell, @"Link", uri.length ? uri : @"Choose a Spotify page or enter a custom link", nil, nil);
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        SGFillCell(cell, @"Icon", SGRTabIconDescription(_draft[SGRNavbarIcon]), nil, nil);
        cell.accessoryView = SGRTabIconAccessory(_draft[SGRNavbarIcon]);
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    return cell;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _nameField.text = _draft[SGRNavbarTitle];
    if (self.isViewLoaded) [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationNone];
    self.navigationItem.rightBarButtonItem.enabled = [_draft[SGRNavbarURI] length] > 0;
}

- (void)nameChanged:(UITextField *)field {
    _draft[SGRNavbarTitle] = field.text ?: @"";
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];
    if (path.section != 1) return;
    [_nameField resignFirstResponder];
    UIViewController *page = path.row == 0 ? [[SGRTabLinkPickerPage alloc] initWithDraft:_draft]
                                           : [[SGRTabIconPickerPage alloc] initWithDraft:_draft];
    [self.navigationController pushViewController:page animated:YES];
}

- (void)cancel {
    [_nameField resignFirstResponder];
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (void)add {
    [_nameField resignFirstResponder];
    NSString *uri = _draft[SGRNavbarURI];
    if (!uri.length) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Choose a link" message:@"Select a Spotify page or enter a custom Spotify link first." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    NSString *title = [_draft[SGRNavbarTitle] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    appendTab(@{SGRNavbarTitle: title.length ? title : uri, SGRNavbarURI: uri, SGRNavbarIcon: _draft[SGRNavbarIcon] ?: @"star"});
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}
@end

@implementation SGRTabLinkPickerPage {
    NSMutableDictionary *_draft;
    NSArray<NSDictionary *> *_presets;
}

- (instancetype)initWithDraft:(NSMutableDictionary *)draft {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    _draft = draft;
    _presets = openablePresets();
    self.title = @"Choose a Link";
    return self;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)table { return 2; }
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section { return section == 0 ? (NSInteger)_presets.count : 1; }
- (UIView *)tableView:(UITableView *)table viewForHeaderInSection:(NSInteger)section {
    return SGSectionHeader(table, section == 0 ? @"Spotify's pages" : @"Custom link");
}
- (CGFloat)tableView:(UITableView *)table heightForHeaderInSection:(NSInteger)section { return SGSectionHeaderHeight; }
- (CGFloat)tableView:(UITableView *)table heightForFooterInSection:(NSInteger)section { return CGFLOAT_MIN; }
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = SGDequeueCell(table, @"tab-link");
    if (path.section == 0) {
        NSDictionary *tab = _presets[(NSUInteger)path.row];
        SGFillCell(cell, tab[SGRNavbarTitle], tab[SGRNavbarURI], nil, nil);
    } else {
        SGFillCell(cell, @"Enter a custom link…", @"Paste a Spotify share link or spotify: URI", nil, @"link");
    }
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    return cell;
}
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];
    if (path.section == 0) {
        NSDictionary *tab = _presets[(NSUInteger)path.row];
        _draft[SGRNavbarURI] = tab[SGRNavbarURI];
        if (![_draft[SGRNavbarTitle] length]) _draft[SGRNavbarTitle] = tab[SGRNavbarTitle];
        if (![_draft[SGRTabDraftIconChosen] boolValue]) _draft[SGRNavbarIcon] = tab[SGRNavbarIcon];
        [self.navigationController popViewControllerAnimated:YES];
        return;
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Custom link" message:@"Paste a Spotify share link or enter a spotify: URI." preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"spotify:playlist:… or open.spotify.com/…";
        field.text = _draft[SGRNavbarURI];
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.keyboardType = UIKeyboardTypeURL;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Use Link" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSURL *url = SGSpotifyURIFromText(alert.textFields.firstObject.text);
        if (!url) {
            [self showLinkError:@"Enter a Spotify share link or spotify: URI."];
            return;
        }
        NSString *via = nil;
        SGLinkRoute route = SGSpotifyURIRoute(url, &via);
        SGLog(@"navbar: custom %@ -> %@", url.absoluteString,
              route == SGLinkRouteOpens ? via : route == SGLinkRouteNone ? @"no handler" : @"unknown");
        if (route == SGLinkRouteNone) {
            [self showLinkError:[NSString stringWithFormat:@"Spotify has nowhere to open %@.", url.absoluteString]];
            return;
        }
        _draft[SGRNavbarURI] = url.absoluteString;
        if (![_draft[SGRNavbarTitle] length]) _draft[SGRNavbarTitle] = url.absoluteString;
        [self.navigationController popViewControllerAnimated:YES];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)showLinkError:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Can't use that link" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
@end

static BOOL SGRTabEncoreHasGlyph(Class iconClass, NSString *name) {
    SEL selector = NSSelectorFromString(name);
    if (!iconClass || ![iconClass respondsToSelector:selector]) return NO;
    id (*iconFor)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
    id icon = iconFor(iconClass, selector);
    return icon && [icon respondsToSelector:@selector(name)];
}

static NSArray<NSString *> *SGRTabEncoreIconNames(void) {
    static NSArray<NSString *> *names;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSArray<NSString *> *priority = @[
            @"home", @"search", @"collection", @"heart", @"playlist", @"album", @"artist", @"podcasts", @"audiobook", @"downloaded",
            @"bookmark", @"browse", @"star", @"user", @"events", @"queue", @"plus", @"radio", @"gears", @"spotifyLogo",
            @"play", @"pause", @"previous", @"next", @"shuffle", @"repeat", @"devices", @"download", @"headphones", @"microphone",
            @"lyrics", @"clock", @"history", @"folder", @"music", @"musicNote", @"musicNoteList", @"userPlus", @"add", @"link",
            @"menu", @"more", @"settings", @"volume", @"volumeDown", @"volumeUp", @"volumeOff", @"checkmark", @"close", @"list",
        ];
        Class iconClass = NSClassFromString(@"SPTEncoreIcon");
        NSMutableArray<NSString *> *available = [NSMutableArray array];
        for (NSString *name in priority) if (SGRTabEncoreHasGlyph(iconClass, name)) [available addObject:name];
        unsigned int methodCount = 0;
        Method *methods = iconClass ? class_copyMethodList(object_getClass(iconClass), &methodCount) : NULL;
        for (unsigned int i = 0; i < methodCount && available.count < 50; i++) {
            NSString *name = NSStringFromSelector(method_getName(methods[i]));
            if ([name containsString:@":"] || [available containsObject:name] || [name hasPrefix:@"_"]) continue;
            if (!SGRTabEncoreHasGlyph(iconClass, name)) continue;
            [available addObject:name];
        }
        free(methods);
        if (available.count > 50) [available removeObjectsInRange:NSMakeRange(50, available.count - 50)];
        names = [available copy];
    });
    return names;
}

static NSArray<NSString *> *SGRTabSFSymbolNames(void) {
    static NSArray<NSString *> *names;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSArray<NSString *> *candidates = @[
            @"house.fill", @"magnifyingglass", @"square.stack.3d.up.fill", @"heart.fill", @"music.note.list", @"music.note", @"music.mic", @"person.crop.circle.fill", @"mic.fill", @"headphones",
            @"arrow.down.circle.fill", @"bookmark.fill", @"sparkles", @"star.fill", @"person.2.fill", @"dot.radiowaves.left.and.right", @"gearshape.fill", @"plus", @"link", @"list.bullet",
            @"clock", @"clock.arrow.circlepath", @"tray.and.arrow.down.fill", @"folder.fill", @"waveform", @"chart.bar.fill", @"globe.americas.fill", @"flame.fill", @"moon.stars.fill", @"sun.max.fill",
            @"bolt.fill", @"play.circle.fill", @"shuffle", @"repeat", @"antenna.radiowaves.left.and.right", @"ear", @"guitar", @"pianokeys", @"drum", @"ticket.fill",
            @"calendar", @"mappin.and.ellipse", @"bag.fill", @"tv.fill", @"video.fill", @"speaker.wave.2.fill", @"airplayaudio", @"ellipsis.circle.fill", @"clock.fill", @"arrow.up.right.circle.fill",
            @"person.fill", @"play.fill", @"pause.fill", @"backward.fill", @"forward.fill", @"globe", @"square.and.arrow.down.fill", @"square.and.arrow.up", @"line.3.horizontal.decrease", @"music.note.tv.fill",
            @"line.3.horizontal.decrease.circle", @"square.grid.2x2.fill", @"square.and.arrow.down", @"clock.fill", @"calendar.badge.clock", @"checkmark", @"ellipsis.circle", @"quote.bubble", @"text.bubble", @"person.crop.circle",
            @"person.crop.circle.badge.plus", @"person.3.fill", @"location.fill", @"ticket", @"tag.fill", @"hand.thumbsup.fill", @"hand.thumbsdown.fill", @"safari.fill", @"speaker.slash.fill", @"waveform.circle.fill",
            @"music.note.house.fill", @"speaker.wave.3.fill", @"bolt", @"backward.end.fill", @"forward.end.fill", @"arrow.uturn.backward", @"square.grid.3x3.fill", @"rectangle.stack.fill", @"list.bullet.rectangle", @"person.crop.square.fill.and.at.rectangle",
        ];
        NSMutableArray<NSString *> *available = [NSMutableArray array];
        for (NSString *name in candidates) if ([UIImage systemImageNamed:name]) [available addObject:name];
        names = [[available subarrayWithRange:NSMakeRange(0, MIN((NSUInteger)50, available.count))] copy];
    });
    return names;
}

@implementation SGRTabIconPickerPage {
    NSMutableDictionary *_draft;
    UISegmentedControl *_catalog;
    NSArray<NSString *> *_encore;
    NSArray<NSString *> *_symbols;
}
- (instancetype)initWithDraft:(NSMutableDictionary *)draft {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    _draft = draft;
    _encore = SGRTabEncoreIconNames();
    _symbols = SGRTabSFSymbolNames();
    self.title = @"Choose an Icon";
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.bounds.size.width, 56)];
    _catalog = [[UISegmentedControl alloc] initWithItems:@[@"Spotify Encore", @"SF Symbols"]];
    _catalog.selectedSegmentIndex = 0;
    _catalog.selectedSegmentTintColor = SGGreen();
    [_catalog setTitleTextAttributes:@{NSForegroundColorAttributeName: UIColor.whiteColor} forState:UIControlStateNormal];
    [_catalog setTitleTextAttributes:@{NSForegroundColorAttributeName: UIColor.blackColor} forState:UIControlStateSelected];
    [_catalog addTarget:self action:@selector(catalogChanged:) forControlEvents:UIControlEventValueChanged];
    _catalog.frame = CGRectMake(16, 8, MAX(0, header.bounds.size.width - 32), 40);
    _catalog.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [header addSubview:_catalog];
    self.tableView.tableHeaderView = header;
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    UIView *header = self.tableView.tableHeaderView;
    CGFloat width = self.tableView.bounds.size.width;
    if (header && header.bounds.size.width != width) {
        header.frame = CGRectMake(0, 0, width, 56);
        _catalog.frame = CGRectMake(16, 8, MAX(0, width - 32), 40);
        self.tableView.tableHeaderView = header;
    }
}
- (void)catalogChanged:(UISegmentedControl *)sender { [self.tableView reloadData]; }
- (NSArray<NSString *> *)iconNames { return _catalog.selectedSegmentIndex == 0 ? _encore : _symbols; }
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section { return (NSInteger)self.iconNames.count; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)table { return 1; }
- (CGFloat)tableView:(UITableView *)table heightForFooterInSection:(NSInteger)section { return CGFLOAT_MIN; }
- (CGFloat)tableView:(UITableView *)table heightForRowAtIndexPath:(NSIndexPath *)path { return 52; }
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = SGDequeueCell(table, @"tab-icon");
    NSString *name = self.iconNames[(NSUInteger)path.row];
    SGFillCell(cell, name, nil, nil, nil);
    cell.accessoryView = SGRTabIconPreview(_catalog.selectedSegmentIndex == 0 ? name : [@"sf:" stringByAppendingString:name], 28);
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    return cell;
}
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];
    NSString *name = self.iconNames[(NSUInteger)path.row];
    _draft[SGRNavbarIcon] = _catalog.selectedSegmentIndex == 0 ? name : [@"sf:" stringByAppendingString:name];
    _draft[SGRTabDraftIconChosen] = @YES;
    [self.navigationController popViewControllerAnimated:YES];
}
@end

static void SGRPresentTabEditor(UIViewController *owner) {
    NSMutableDictionary *draft = [@{SGRNavbarTitle: @"", SGRNavbarURI: @"", SGRNavbarIcon: @"star", SGRTabDraftIconChosen: @NO} mutableCopy];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:[[SGRTabEditorPage alloc] initWithDraft:draft]];
    navigation.modalPresentationStyle = UIModalPresentationPageSheet;
    navigation.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    UISheetPresentationController *sheet = navigation.sheetPresentationController;
    if (sheet) {
        sheet.detents = @[[UISheetPresentationControllerDetent mediumDetent], [UISheetPresentationControllerDetent largeDetent]];
        sheet.selectedDetentIdentifier = UISheetPresentationControllerDetentIdentifierMedium;
        sheet.prefersGrabberVisible = YES;
        sheet.preferredCornerRadius = 24;
        sheet.prefersScrollingExpandsWhenScrolledToEdge = YES;
    }
    [owner presentViewController:navigation animated:YES completion:nil];
}

typedef NS_ENUM(NSInteger, SGRNavbarSection) {
    SGRNavbarSectionSwitch,
    SGRNavbarSectionTabs,
    SGRNavbarSectionAdd,
    SGRNavbarSectionReset,
    SGRNavbarSectionCount,
};

// The tabs, in the order the bar shows them: drag to reorder, tap to show or hide, swipe a tab of
// your own away. Spotify's own tabs can only be hidden, never removed. Mod Settings and the welcome
// tour show the same editor.
@interface SGRNavbarPage : SGPage
@end

@implementation SGRNavbarPage {
    NSMutableArray<NSMutableDictionary *> *_entries;
    UIView *_intro;
}

- (instancetype)init {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.title = @"Navbar";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.allowsSelectionDuringEditing = YES;
    self.tableView.editing = YES;
    _intro = SGNote(@"Drag to reorder, tap to show or hide.");
    self.tableView.tableHeaderView = _intro;
    _entries = navbarEntries();
}

// The Add page writes straight to the layout, so the list is read again on the way back.
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _entries = navbarEntries();
    [self.tableView reloadData];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    SGFitNote(self.tableView, _intro, 24, 0);
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    SGInsetForBars(self.tableView);
}

- (void)save {
    SGRSetNavbarLayout(_entries);
    SGRRefreshTabBar();
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)table {
    return SGRNavbarSectionCount;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    if (section == SGRNavbarSectionSwitch) return 2;
    return section == SGRNavbarSectionTabs ? (NSInteger)_entries.count : 1;
}

- (NSString *)headerFor:(NSInteger)section {
    return section == SGRNavbarSectionTabs ? @"Tabs" : nil;
}

- (UIView *)tableView:(UITableView *)table viewForHeaderInSection:(NSInteger)section {
    NSString *title = [self headerFor:section];
    return title ? SGSectionHeader(table, title) : nil;
}

- (CGFloat)tableView:(UITableView *)table heightForHeaderInSection:(NSInteger)section {
    if ([self headerFor:section]) return SGSectionHeaderHeight;
    return [self tableView:table numberOfRowsInSection:section] ? SGSectionGap : CGFLOAT_MIN;
}

- (CGFloat)tableView:(UITableView *)table heightForFooterInSection:(NSInteger)section {
    return CGFLOAT_MIN;
}

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = SGDequeueCell(table, @"navbar");
    switch (path.section) {
        case SGRNavbarSectionSwitch: {
            BOOL labels = path.row == 1;
            SGFillCell(cell, labels ? @"Hide labels" : @"Custom navbar", labels ? @"Icons only" : nil, nil, nil);
            UISwitch *toggle = [UISwitch new];
            toggle.onTintColor = SGGreen();
            toggle.tag = path.row;
            toggle.on = labels ? SGHidden(SGRKeyNavbarHideLabels) : SGEnabled(SGRKeyNavbar);
            [toggle addTarget:self action:@selector(toggled:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = toggle;
            break;
        }
        case SGRNavbarSectionTabs: {
            NSDictionary *entry = _entries[(NSUInteger)path.row];
            BOOL hidden = [entry[SGRNavbarHidden] boolValue];
            NSString *uri = entry[SGRNavbarURI];
            SGFillCell(cell, entry[SGRNavbarTitle], hidden ? @"Hidden" : (uri ?: @"Spotify's own tab"),
                     hidden ? SGGrey() : nil, hidden ? @"eye.slash" : @"eye");
            break;
        }
        case SGRNavbarSectionAdd:
            SGFillCell(cell, @"Add a tab…", nil, nil, @"plus");
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            break;
        default:
            SGFillCell(cell, @"Use Spotify's order", nil, nil, @"arrow.uturn.backward");
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            break;
    }
    return cell;
}

- (BOOL)tableView:(UITableView *)table canMoveRowAtIndexPath:(NSIndexPath *)path {
    return path.section == SGRNavbarSectionTabs;
}

- (BOOL)tableView:(UITableView *)table canEditRowAtIndexPath:(NSIndexPath *)path {
    return path.section == SGRNavbarSectionTabs;
}

// Spotify's own tabs stay on the list to be switched back on; only the mod's own can go.
- (UITableViewCellEditingStyle)tableView:(UITableView *)table editingStyleForRowAtIndexPath:(NSIndexPath *)path {
    if (path.section != SGRNavbarSectionTabs) return UITableViewCellEditingStyleNone;
    return _entries[(NSUInteger)path.row][SGRNavbarURI] ? UITableViewCellEditingStyleDelete : UITableViewCellEditingStyleNone;
}

- (NSIndexPath *)tableView:(UITableView *)table targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)from toProposedIndexPath:(NSIndexPath *)to {
    return to.section == SGRNavbarSectionTabs ? to : from;
}

- (void)tableView:(UITableView *)table moveRowAtIndexPath:(NSIndexPath *)from toIndexPath:(NSIndexPath *)to {
    NSMutableDictionary *entry = _entries[(NSUInteger)from.row];
    [_entries removeObjectAtIndex:(NSUInteger)from.row];
    [_entries insertObject:entry atIndex:(NSUInteger)to.row];
    [self save];
}

- (void)tableView:(UITableView *)table commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)path {
    if (style != UITableViewCellEditingStyleDelete) return;
    [_entries removeObjectAtIndex:(NSUInteger)path.row];
    [self save];
    [table deleteRowsAtIndexPaths:@[path] withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];
    if (path.section == SGRNavbarSectionTabs) {
        NSMutableDictionary *entry = _entries[(NSUInteger)path.row];
        entry[SGRNavbarHidden] = [entry[SGRNavbarHidden] boolValue] ? nil : @YES;
        [self save];
        [table reloadRowsAtIndexPaths:@[path] withRowAnimation:UITableViewRowAnimationNone];
    } else if (path.section == SGRNavbarSectionAdd) {
        SGRPresentTabEditor(self);
    } else if (path.section == SGRNavbarSectionReset) {
        [self reset];
    }
}

- (void)toggled:(UISwitch *)toggle {
    SGSetEnabled(toggle.tag == 1 ? SGRKeyNavbarHideLabels : SGRKeyNavbar, toggle.on);
    SGRRefreshTabBar();
}

- (void)reset {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Use Spotify's order"
                                                                  message:@"Every tab of Spotify's comes back where Spotify put it, and the tabs you added go."
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Reset" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        SGRSetNavbarLayout(@[]);
        SGRRefreshTabBar();
        self->_entries = navbarEntries();
        [self.tableView reloadData];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

UIViewController *SGRNavbarSettingsPage(void) {
    return [SGRNavbarPage new];
}

UIViewController *SGRNavbarEditorPage(void) {
    return [SGRNavbarPage new];
}
