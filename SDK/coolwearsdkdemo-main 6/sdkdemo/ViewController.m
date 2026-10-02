//
//  ViewController.m
//  sdkdemo
//
//  Created by coolwear on 2022/9/20.
//

#import "ViewController.h"
#import "FuncListViewController.h"
#import <BluetoothLibrary/BluetoothLibrary.h>
#import "LoadingHUD.h"

@interface ViewController ()<UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *peripheralArr;
@property (nonatomic, strong) SearchPeripheral *sp;
@property (nonatomic, strong) LoadingHUD *loadingHUD;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
        
    [DataReceiver shared];
    self.loadingHUD = [[LoadingHUD alloc] init];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receivePeripherals:) name:ScanPeripheralsNoticeKey object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(connectStatusChanged:) name:ProductStatusChangeNoticeKey object:nil];
    
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.rowHeight = 55;
    [self.view addSubview:self.tableView];
    
    [self setupBottomView];
    
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    [[CEProductK6 shareInstance] startScan];
}

- (void)setupBottomView{
    UIView *bottomView = [UIView new];
    bottomView.tag = 100;
    bottomView.backgroundColor = UIColor.blueColor;
    [self.view addSubview:bottomView];
    
    UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    btn.layer.cornerRadius = 8;
    [btn setTitle:@"开始扫描" forState:UIControlStateNormal];
    [btn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    btn.backgroundColor = UIColor.blueColor;
    [btn addTarget:self action:@selector(scan:) forControlEvents:UIControlEventTouchUpInside];
    [bottomView addSubview:btn];
}

- (void)viewWillLayoutSubviews{
    
    UIView *v1 = [self.view viewWithTag:100];
    CGFloat bh = 44;
    CGFloat safetop = 0;
    if (@available(iOS 11.0, *)) {
        bh = self.view.safeAreaInsets.bottom + 44;
        safetop = self.view.safeAreaInsets.top;
    }
    CGFloat y = self.view.bounds.size.height - bh;
    v1.frame = CGRectMake(0, y, self.view.bounds.size.width, bh);
    self.tableView.frame = CGRectMake(0, safetop, self.view.bounds.size.width, y - safetop);
        
}

- (void)receivePeripherals:(NSNotification *)noti{
    NSArray *peripherals = noti.object;

    NSArray *filteredArray = [peripherals filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        SearchPeripheral *peripheral = (SearchPeripheral *)object;
        return (peripheral.version > 4) || peripheral.isPairedSystem;
    }]];
    
    NSArray *sortedArray = [filteredArray sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        SearchPeripheral *first = (SearchPeripheral *)obj1;
        SearchPeripheral *second = (SearchPeripheral *)obj2;
        return (labs([first.rssi integerValue]) > labs([second.rssi integerValue]));
    }];
    
    self.peripheralArr = sortedArray;
    [self.tableView reloadData];
}

- (void)syncData{}

- (void)connectStatusChanged:(NSNotification *)noti{
    ProductStatus status = [[noti object] intValue];
    if (status == ProductStatus_completed){
        
        [self syncData];
        FuncListViewController* vc = [[FuncListViewController alloc] init];
        vc.sp = self.sp;
        UINavigationController *navc = [[UINavigationController alloc] initWithRootViewController:vc];
        navc.modalPresentationStyle = UIModalPresentationFullScreen;
        [self presentViewController:navc animated:YES completion:nil];
    }
    [self.loadingHUD removeFromSuperview];
}

- (void)scan:(UIButton *)sender{
    
    if ([CEProductK6 shareInstance].status == ProductStatus_powerOff) {
        return;
    }
    [self.loadingHUD showToView:self.view.window];
    [[CEProductK6 shareInstance] startScan];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.loadingHUD removeFromSuperview];
        [[CEProductK6 shareInstance] stopScan];
    });
    
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return self.peripheralArr.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
    }
    SearchPeripheral *peripheral = self.peripheralArr[indexPath.row];
    cell.textLabel.text = peripheral.name;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"ID: %@ MAC: %@",peripheral.deviceID, peripheral.macAddress];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    
    [self.loadingHUD showToView:self.view.window];
    SearchPeripheral *peripheral = self.peripheralArr[indexPath.row];
    self.sp = peripheral;
    [CEProductK6.shareInstance connect:peripheral.peripheral];
}

@end


@implementation ViewController (Sync)



@end
