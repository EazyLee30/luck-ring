//
//  ContactViewController.m
//  sdkdemo
//
//  Created by coolwear on 2022/9/30.
//

#import "ContactViewController.h"

@interface ContactViewController ()<UITableViewDataSource,UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *data;
@end

@implementation ContactViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(syncContactEnd:) name:@"SyncContactEnd" object:nil];
    
    UIBarButtonItem *add = [[UIBarButtonItem alloc] initWithTitle:@"Add" style:UIBarButtonItemStylePlain target:self action:@selector(add:)];
    UIBarButtonItem *del = [[UIBarButtonItem alloc] initWithTitle:@"Del Last" style:UIBarButtonItemStylePlain target:self action:@selector(delLast:)];
    self.navigationItem.rightBarButtonItems = @[add, del];
    
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.rowHeight = 55;
    self.tableView.frame = self.view.bounds;
    [self.view addSubview:self.tableView];
    
    self.data = [NSMutableArray array];
    [self syncData];
}


- (void)add:(id)sender{
    [CE_SyncContactCmd insertWithName:@"test" phone:@"12356780123" handler:nil];
    [self syncData];
}

- (void)delLast:(id)sender{
    [CE_SyncContactCmd deleteAtIndex:self.data.count-1 handler:nil];
    [self syncData];
}


- (void)syncData{
    DataManager.shared.contactData = [NSMutableArray array];
    [CE_SyncContactCmd syncAtIndex:0 handler:nil];
}


- (void)syncContactEnd:(NSNotification *)noti{
    self.data = DataManager.shared.contactData;
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return self.data.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"cell"];
    }
    ContactModel *model = self.data[indexPath.row];
    cell.textLabel.text = model.name;
    cell.detailTextLabel.text = model.tel;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{

}

@end
