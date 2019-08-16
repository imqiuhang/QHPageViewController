//
//  ViewController.m
//  Example
//
//  Created by imqiuhang on 2019/8/16.
//  Copyright © 2019 imqiuhang. All rights reserved.
//

#import "ViewController.h"
#import <QHPageViewController/QHPageViewController.h>

@interface HTCMPageViewChildViewController : UIViewController

@property (nonatomic, assign) NSInteger index;

@end

@interface ViewController ()<QHPageViewControllerDelegate,QHPageViewControllerDataSource>

@property (nonatomic, strong) QHPageViewController *pageView;
@property (nonatomic, assign) NSInteger count;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.count = 10;
    [self setup];
}

- (void)setup {
    
    self.pageView = [[QHPageViewController alloc] initWithOrientation:QHPageViewControllerNavigationOrientationVertical
                                                               delegate:self
                                                             dataSource:self];
    [self addChildViewController:self.pageView];
    [self.view addSubview:self.pageView.view];
    self.pageView.view.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    [self.pageView reload];
    
    [self.pageView moveToControllerAtIndex:1 animation:YES];
}


- (NSInteger)numberOfViewControllersForPageViewController:(QHPageViewController *)pageViewController {
    return self.count;
}

- (UIViewController *)pageViewController:(QHPageViewController *)pageViewController
                  viewControllerForIndex:(NSInteger)index {
    
    NSLog(@"\n---------\n%li>>>>>>>creat\n---------\n",(long)index);
    
    HTCMPageViewChildViewController *vc= [[HTCMPageViewChildViewController alloc] init];
    vc.index = index;
    return vc;
}

- (void)pageViewController:(QHPageViewController *)pageViewController
        didUpdateIndexFrom:(NSInteger)formIndex
                   toIndex:(NSInteger)toIndex {
    NSLog(@"\n---------\n%li>>>>>>>move to >>>>>>>%li\n---------\n",(long)formIndex,(long)toIndex);
}



@end


@interface HTCMPageViewChildViewController ()

@property (nonatomic, strong) UILabel *indexLabel;

@end

@implementation HTCMPageViewChildViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.indexLabel = [[UILabel alloc] init];
    [self.view addSubview:self.indexLabel];
    self.indexLabel.font = [UIFont boldSystemFontOfSize:100];
    self.indexLabel.text = @(self.index).stringValue;
    self.indexLabel.textColor = [UIColor whiteColor];
    CGFloat color = 10*self.index/255.f;
    self.view.backgroundColor = [UIColor colorWithRed:color green:color blue:color alpha:1];
    [self.indexLabel sizeToFit];
    self.indexLabel.center = self.view.center;
}

- (void)dealloc {
    NSLog(@"\n---------\n%li>>>>>>>delloc\n---------\n",(long)self.index);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    NSLog(@"\n---------\n%li>>>>>>>viewWillAppear\n---------\n",(long)self.index);
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    NSLog(@"\n---------\n%li>>>>>>>viewDidAppear\n---------\n",(long)self.index);
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    NSLog(@"\n---------\n%li>>>>>>>viewWillDisappear\n---------\n",(long)self.index);
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    NSLog(@"\n---------\n%li>>>>>>>viewDidDisappear\n---------\n",(long)self.index);
}

@end
