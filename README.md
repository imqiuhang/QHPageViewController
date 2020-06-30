# QHPageViewController
更简单的使用PageViewController，解决UIPageViewController各种姿势的崩溃问题以及繁琐的代理使用。

设计用于应对类似于抖音, 映客, 考拉等类型 APP, 滑动切换视频/直播控制器, 并针对此类场景, 优化了控制器生命周期及页面缓存.

[![License MIT](https://img.shields.io/badge/license-MIT-green.svg?style=flat)](https://raw.githubusercontent.com/ibireme/YYText/master/LICENSE)

Features
==============

 - 支持横向，垂直切换
 - 解决UIPageViewController自带偶现闪退问题
 - 缓存优化，静止时只缓存一个VC，切换时只缓存2个VC，切换后释放多余的，符合视频浏览等常规操作（UIPage一般3个）
 - 子VC生命周期一致性和UIPageViewController子VC一致
 - 切换回调和UIPageViewController回调时机一致，做了计算优化，只有当上一个VC滑出屏幕后才会回调切换
 - API优化，类UITabView方式使用，数据源数量和数据源创建一致，无需UIPage繁琐代理


 ![demo](https://github.com/imqiuhang/QHPageViewController/blob/master/Screenshots/demo.gif)


#### Podfile

To integrate QHPageViewController into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '8.0'

target 'TargetName' do
pod 'QHPageViewController', '~> 0.1.0'
end
```

 

Usage
==============

```objc

- (void)setup {
    
    // Vertical or Horizontal
    self.pageView = [[QHPageViewController alloc] initWithOrientation:QHPageViewControllerNavigationOrientationVertical
                                                               delegate:self
                                                             dataSource:self];
                                                             
    // add to parent‘s lifecycle
    [self addChildViewController:self.pageView];
    [self.view addSubview:self.pageView.view];
    self.pageView.view.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    //类似tableView，任何时候reload
    [self.pageView reload];
    //手动move
    [self.pageView moveToControllerAtIndex:1 animation:YES];
}

//数据源
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

//回调
- (void)pageViewController:(QHPageViewController *)pageViewController
        didUpdateIndexFrom:(NSInteger)formIndex
                   toIndex:(NSInteger)toIndex {
    NSLog(@"\n---------\n%li>>>>>>>move to >>>>>>>%li\n---------\n",(long)formIndex,(long)toIndex);
}


```


 生命周期对比
==============


```objc
 i】表示tab所在的index
 ---------------------------------------------------------
 * 从【0】慢慢上滑露出【1】，然后放手重新回弹到了【0】这个过程
 
 ==== UIPageViewController ====
 【1】####### init
 【1】>>>>>>> viewWillAppear
 【0】>>>>>>> viewWillDisappear
 【0】>>>>>>> viewWillAppear
 【0】>>>>>>> viewDidAppear
 【1】>>>>>>> viewWillDisappear
 【1】>>>>>>> viewDidDisappear
 
 ==== QHPageViewController ====
 【1】####### init
 【1】>>>>>>> viewWillAppear
 【0】>>>>>>> viewWillDisappear
 【1】>>>>>>> viewWillDisappear
 【1】>>>>>>> viewDidDisappear
 【1】####### delloc (这里有所不同，因为我们只缓存当前在屏幕上的VC，消失即释放)
 【0】>>>>>>>viewWillAppear
 【0】>>>>>>>viewDidAppear
 
 ---------------------------------------------------------
 * 从【0】直接滑到【1】，包括手动滑动或者调用接口切换
 ==== UIPageViewController ====
 【1】>>>>>>> viewWillAppear
 【0】>>>>>>> viewWillDisappear
 【1】>>>>>>> viewDidAppear
 【0】>>>>>>> viewDidDisappear
 
 ==== QHPageViewController ====
 【1】>>>>>>> viewWillAppear
 【0】>>>>>>> viewWillDisappear
 【1】>>>>>>> viewDidAppear
 【0】####### delloc
 
```