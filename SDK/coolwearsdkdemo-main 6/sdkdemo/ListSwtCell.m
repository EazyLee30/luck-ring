//
//  ListSwtCell.m
//  sdkdemo
//
//  Created by coolwear on 2023/5/5.
//

#import "ListSwtCell.h"

@implementation ListSwtCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier{
    if (self = [super initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:reuseIdentifier]){
        _swt = [[UISwitch alloc] initWithFrame:CGRectMake(0, 0, 60, 30)];
        self.accessoryView = _swt;

    }
    return self;
}
@end
