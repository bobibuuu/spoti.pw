#import "Core/SGCore.h"
#import "Settings/SGPage.h"
#import "Settings/SGPageStyle.h"
#import "Headers/SPTEncoreIconView.h"
#import "Shared/Navigation/Links.h"
#import "Navbar.h"
#import <objc/message.h>
#import <objc/runtime.h>
#import <stdlib.h>

// What "Add a tab" offers: URIs Spotify's own router resolves to a page of its own, each with the
// name of the SPTEncoreIcon class method that draws its glyph.
static NSArray<NSDictionary *> *tabPresets(void) {
    return @[
        @{SGNavbarTitle: @"Home", SGNavbarURI: @"spotify:home", SGNavbarIcon: @"home"},
        @{SGNavbarTitle: @"Search", SGNavbarURI: @"spotify:search", SGNavbarIcon: @"search"},
        @{SGNavbarTitle: @"Your Library", SGNavbarURI: @"spotify:collection", SGNavbarIcon: @"collection"},
        @{SGNavbarTitle: @"Liked Songs", SGNavbarURI: @"spotify:collection:tracks", SGNavbarIcon: @"heart"},
        @{SGNavbarTitle: @"Playlists", SGNavbarURI: @"spotify:playlists", SGNavbarIcon: @"playlist"},
        @{SGNavbarTitle: @"Albums", SGNavbarURI: @"spotify:collection:albums", SGNavbarIcon: @"album"},
        @{SGNavbarTitle: @"Artists", SGNavbarURI: @"spotify:collection:artists", SGNavbarIcon: @"artist"},
        @{SGNavbarTitle: @"Podcasts", SGNavbarURI: @"spotify:collection:podcasts", SGNavbarIcon: @"podcasts"},
        @{SGNavbarTitle: @"Audiobooks", SGNavbarURI: @"spotify:collection:audiobooks", SGNavbarIcon: @"audiobook"},
        @{SGNavbarTitle: @"Downloads", SGNavbarURI: @"spotify:collection:downloads", SGNavbarIcon: @"downloaded"},
        @{SGNavbarTitle: @"Your Episodes", SGNavbarURI: @"spotify:collection:your-episodes", SGNavbarIcon: @"bookmark"},
        @{SGNavbarTitle: @"Browse", SGNavbarURI: @"spotify:browse", SGNavbarIcon: @"browse"},
        @{SGNavbarTitle: @"New Releases", SGNavbarURI: @"spotify:new-releases", SGNavbarIcon: @"star"},
        @{SGNavbarTitle: @"Made For You", SGNavbarURI: @"spotify:made-for-you", SGNavbarIcon: @"user"},
        @{SGNavbarTitle: @"Concerts", SGNavbarURI: @"spotify:concerts", SGNavbarIcon: @"events"},
        @{SGNavbarTitle: @"Queue", SGNavbarURI: @"spotify:now-playing:queue", SGNavbarIcon: @"queue"},
        @{SGNavbarTitle: @"Create", SGNavbarURI: @"spotify:create-menu", SGNavbarIcon: @"plus"},
    ];
}

// The list the Navbar page edits: the saved order first, then every tab of Spotify's it does not
// name, in Spotify's order. Entries for tabs Spotify no longer has drop out.
static NSMutableArray<NSMutableDictionary *> *navbarEntries(void) {
    NSArray<NSString *> *stock = SGNavbarStock();
    NSMutableArray<NSMutableDictionary *> *entries = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    for (NSDictionary *entry in SGNavbarLayout()) {
        NSString *ident = entry[SGNavbarID];
        if (![ident isKindOfClass:NSString.class] || [seen containsObject:ident]) continue;
        if (!entry[SGNavbarURI] && ![stock containsObject:ident]) continue;
        [seen addObject:ident];
        [entries addObject:[entry mutableCopy]];
    }
    for (NSString *ident in stock) {
        if ([seen containsObject:ident]) continue;
        [entries addObject:[@{SGNavbarID: ident, SGNavbarTitle: ident} mutableCopy]];
    }
    return entries;
}

// A tab of the mod's own carries an identity of its own, so the same page can sit on the bar twice
// and renaming one does not shuffle the order.
static void appendTab(NSDictionary *tab) {
    NSMutableDictionary *entry = [tab mutableCopy];
    entry[SGNavbarID] = NSUUID.UUID.UUIDString;
    SGSetNavbarLayout([navbarEntries() arrayByAddingObject:entry]);
    SGRefreshTabBar();
}

static NSString *const SGTabDraftIconChosen = @"iconChosen";

static UIView *SGTabIconPreview(NSString *name, CGFloat size) {
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

static NSString *SGTabIconDescription(NSString *name) {
    if ([name hasPrefix:@"sf:"]) return [NSString stringWithFormat:@"SF Symbols · %@", [name substringFromIndex:3]];
    return [NSString stringWithFormat:@"Spotify Encore · %@", name.length ? name : @"star"];
}

static UIView *SGTabIconAccessory(NSString *name) {
    UIView *accessory = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 52, 28)];
    UIView *preview = SGTabIconPreview(name, 24);
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
        SGLinkRoute route = SGSpotifyURIRoute([NSURL URLWithString:tab[SGNavbarURI]], &via);
        SGLog(@"navbar: preset %@ -> %@", tab[SGNavbarURI],
              route == SGLinkRouteOpens ? via : route == SGLinkRouteNone ? @"no handler, left out" : @"unknown");
        if (route != SGLinkRouteNone) [kept addObject:tab];
    }
    return kept;
}

@interface SGTabLinkPickerPage : SGPage
- (instancetype)initWithDraft:(NSMutableDictionary *)draft;
- (void)showLinkError:(NSString *)message;
@end

@interface SGTabIconPickerPage : SGPage
- (instancetype)initWithDraft:(NSMutableDictionary *)draft;
@end

@interface SGTabEditorPage : SGPage <UITextFieldDelegate>
- (instancetype)initWithDraft:(NSMutableDictionary *)draft;
@end

@implementation SGTabEditorPage {
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
    self.navigationItem.rightBarButtonItem.enabled = [_draft[SGNavbarURI] length] > 0;
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
        field.text = _draft[SGNavbarTitle];
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
        NSString *uri = _draft[SGNavbarURI];
        SGFillCell(cell, @"Link", uri.length ? uri : @"Choose a Spotify page or enter a custom link", nil, nil);
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        SGFillCell(cell, @"Icon", SGTabIconDescription(_draft[SGNavbarIcon]), nil, nil);
        cell.accessoryView = SGTabIconAccessory(_draft[SGNavbarIcon]);
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    return cell;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _nameField.text = _draft[SGNavbarTitle];
    if (self.isViewLoaded) [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationNone];
    self.navigationItem.rightBarButtonItem.enabled = [_draft[SGNavbarURI] length] > 0;
}

- (void)nameChanged:(UITextField *)field {
    _draft[SGNavbarTitle] = field.text ?: @"";
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];
    if (path.section != 1) return;
    [_nameField resignFirstResponder];
    UIViewController *page = path.row == 0 ? [[SGTabLinkPickerPage alloc] initWithDraft:_draft]
                                           : [[SGTabIconPickerPage alloc] initWithDraft:_draft];
    [self.navigationController pushViewController:page animated:YES];
}

- (void)cancel {
    [_nameField resignFirstResponder];
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (void)add {
    [_nameField resignFirstResponder];
    NSString *uri = _draft[SGNavbarURI];
    if (!uri.length) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Choose a link" message:@"Select a Spotify page or enter a custom Spotify link first." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    NSString *title = [_draft[SGNavbarTitle] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    appendTab(@{SGNavbarTitle: title.length ? title : uri, SGNavbarURI: uri, SGNavbarIcon: _draft[SGNavbarIcon] ?: @"star"});
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}
@end

@implementation SGTabLinkPickerPage {
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
        SGFillCell(cell, tab[SGNavbarTitle], tab[SGNavbarURI], nil, nil);
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
        _draft[SGNavbarURI] = tab[SGNavbarURI];
        if (![_draft[SGNavbarTitle] length]) _draft[SGNavbarTitle] = tab[SGNavbarTitle];
        if (![_draft[SGTabDraftIconChosen] boolValue]) _draft[SGNavbarIcon] = tab[SGNavbarIcon];
        [self.navigationController popViewControllerAnimated:YES];
        return;
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Custom link" message:@"Paste a Spotify share link or enter a spotify: URI." preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"spotify:playlist:… or open.spotify.com/…";
        field.text = _draft[SGNavbarURI];
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
        _draft[SGNavbarURI] = url.absoluteString;
        if (![_draft[SGNavbarTitle] length]) _draft[SGNavbarTitle] = url.absoluteString;
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

static BOOL SGTabEncoreHasGlyph(Class iconClass, NSString *name) {
    SEL selector = NSSelectorFromString(name);
    if (!iconClass || ![iconClass respondsToSelector:selector]) return NO;
    id (*iconFor)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
    id icon = iconFor(iconClass, selector);
    return icon && [icon respondsToSelector:@selector(name)];
}

static NSArray<NSString *> *SGTabEncoreIconNames(void) {
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
        for (NSString *name in priority) if (SGTabEncoreHasGlyph(iconClass, name)) [available addObject:name];
        unsigned int methodCount = 0;
        Method *methods = iconClass ? class_copyMethodList(object_getClass(iconClass), &methodCount) : NULL;
        for (unsigned int i = 0; i < methodCount && available.count < 50; i++) {
            NSString *name = NSStringFromSelector(method_getName(methods[i]));
            if ([name containsString:@":"] || [available containsObject:name] || [name hasPrefix:@"_"]) continue;
            if (!SGTabEncoreHasGlyph(iconClass, name)) continue;
            [available addObject:name];
        }
        free(methods);
        if (available.count > 50) [available removeObjectsInRange:NSMakeRange(50, available.count - 50)];
        names = [available copy];
    });
    return names;
}

static NSArray<NSString *> *SGTabSFSymbolNames(void) {
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

@implementation SGTabIconPickerPage {
    NSMutableDictionary *_draft;
    UISegmentedControl *_catalog;
    NSArray<NSString *> *_encore;
    NSArray<NSString *> *_symbols;
}
- (instancetype)initWithDraft:(NSMutableDictionary *)draft {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    _draft = draft;
    _encore = SGTabEncoreIconNames();
    _symbols = SGTabSFSymbolNames();
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
    cell.accessoryView = SGTabIconPreview(_catalog.selectedSegmentIndex == 0 ? name : [@"sf:" stringByAppendingString:name], 28);
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    return cell;
}
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];
    NSString *name = self.iconNames[(NSUInteger)path.row];
    _draft[SGNavbarIcon] = _catalog.selectedSegmentIndex == 0 ? name : [@"sf:" stringByAppendingString:name];
    _draft[SGTabDraftIconChosen] = @YES;
    [self.navigationController popViewControllerAnimated:YES];
}
@end

static void SGPresentTabEditor(UIViewController *owner) {
    NSMutableDictionary *draft = [@{SGNavbarTitle: @"", SGNavbarURI: @"", SGNavbarIcon: @"star", SGTabDraftIconChosen: @NO} mutableCopy];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:[[SGTabEditorPage alloc] initWithDraft:draft]];
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

typedef NS_ENUM(NSInteger, SGNavbarSection) {
    SGNavbarSectionSwitch,
    SGNavbarSectionTabs,
    SGNavbarSectionAdd,
    SGNavbarSectionReset,
    SGNavbarSectionCount,
};

// The tabs, in the order the bar shows them: drag to reorder, tap to show or hide, swipe a tab of
// your own away. Spotify's own tabs can only be hidden, never removed. Mod Settings and the welcome
// tour show the same editor.
@interface SGNavbarPage : SGPage
@end

@implementation SGNavbarPage {
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
    SGSetNavbarLayout(_entries);
    SGRefreshTabBar();
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)table {
    return SGNavbarSectionCount;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    return section == SGNavbarSectionTabs ? (NSInteger)_entries.count : 1;
}

- (NSString *)headerFor:(NSInteger)section {
    return section == SGNavbarSectionTabs ? @"Tabs" : nil;
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
        case SGNavbarSectionSwitch: {
            SGFillCell(cell, @"Custom navbar", nil, nil, nil);
            UISwitch *toggle = [UISwitch new];
            toggle.onTintColor = SGGreen();
            toggle.on = SGEnabled(SGKeyNavbar);
            [toggle addTarget:self action:@selector(toggled:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = toggle;
            break;
        }
        case SGNavbarSectionTabs: {
            NSDictionary *entry = _entries[(NSUInteger)path.row];
            BOOL hidden = [entry[SGNavbarHidden] boolValue];
            NSString *uri = entry[SGNavbarURI];
            SGFillCell(cell, entry[SGNavbarTitle], hidden ? @"Hidden" : (uri ?: @"Spotify's own tab"),
                     hidden ? SGGrey() : nil, hidden ? @"eye.slash" : @"eye");
            break;
        }
        case SGNavbarSectionAdd:
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
    return path.section == SGNavbarSectionTabs;
}

- (BOOL)tableView:(UITableView *)table canEditRowAtIndexPath:(NSIndexPath *)path {
    return path.section == SGNavbarSectionTabs;
}

// Spotify's own tabs stay on the list to be switched back on; only the mod's own can go.
- (UITableViewCellEditingStyle)tableView:(UITableView *)table editingStyleForRowAtIndexPath:(NSIndexPath *)path {
    if (path.section != SGNavbarSectionTabs) return UITableViewCellEditingStyleNone;
    return _entries[(NSUInteger)path.row][SGNavbarURI] ? UITableViewCellEditingStyleDelete : UITableViewCellEditingStyleNone;
}

- (NSIndexPath *)tableView:(UITableView *)table targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)from toProposedIndexPath:(NSIndexPath *)to {
    return to.section == SGNavbarSectionTabs ? to : from;
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
    if (path.section == SGNavbarSectionTabs) {
        NSMutableDictionary *entry = _entries[(NSUInteger)path.row];
        entry[SGNavbarHidden] = [entry[SGNavbarHidden] boolValue] ? nil : @YES;
        [self save];
        [table reloadRowsAtIndexPaths:@[path] withRowAnimation:UITableViewRowAnimationNone];
    } else if (path.section == SGNavbarSectionAdd) {
        SGPresentTabEditor(self);
    } else if (path.section == SGNavbarSectionReset) {
        [self reset];
    }
}

- (void)toggled:(UISwitch *)toggle {
    SGSetEnabled(SGKeyNavbar, toggle.on);
    SGRefreshTabBar();
}

- (void)reset {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Use Spotify's order"
                                                                  message:@"Every tab of Spotify's comes back where Spotify put it, and the tabs you added go."
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Reset" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        SGSetNavbarLayout(@[]);
        SGRefreshTabBar();
        self->_entries = navbarEntries();
        [self.tableView reloadData];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

UIViewController *SGNavbarSettingsPage(void) {
    return [SGNavbarPage new];
}

UIViewController *SGNavbarEditorPage(void) {
    return [SGNavbarPage new];
}
