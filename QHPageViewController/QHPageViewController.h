//
//  QHPageViewController.h
//
//
//  Created by imqiuhang on 2019/6/28.
//

/*
 
 ******* ******* ******* *******
 @Feature
 * 支持横向，垂直切换
 * 解决UIPageViewController自带偶现闪退问题
 * 缓存优化，静止时只缓存一个VC，切换时只缓存2个VC，切换后释放多余的，符合视频浏览等常规操作（UIPage一般3个）
 * 子VC生命周期一致性和UIPageViewController子VC一致
 * 切换回调和UIPageViewController回调时机一致，做了计算优化，只有当上一个VC滑出屏幕后才会回调切换
 * API优化，类UITabView方式使用，数据源数量和数据源创建一致，无需UIPage繁琐代理
 ******* ******* ******* *******
 
 ////////////////////////////生命周期对比////////////////////////////
 【i】表示tab所在的index
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
 
 */

typedef NS_ENUM(NSUInteger, QHPageViewControllerNavigationOrientation) {
    QHPageViewControllerNavigationOrientationHorizontal = 0,//  |-|
    QHPageViewControllerNavigationOrientationVertical   = 1,//  工
};

@protocol  QHPageViewControllerDelegate,QHPageViewControllerDataSource;

@interface QHPageViewController : UIViewController

#pragma mark - init
- (instancetype)initWithOrientation:(QHPageViewControllerNavigationOrientation)orientation
                           delegate:(id<QHPageViewControllerDelegate>)delegate
                         dataSource:(id<QHPageViewControllerDataSource>)dataSource NS_DESIGNATED_INITIALIZER;

#pragma mark - getter
@property (nonatomic, assign, readonly) QHPageViewControllerNavigationOrientation orientation;

#pragma mark - control

//cleanCache = NO
- (void)reload;

/*
 * 仅仅是更新数据源的个数
 * cleanCache 是否删除缓存的VC，包括当前屏幕内的VC
 */
- (void)reloadWithCleanCache:(BOOL)cleanCache;

/*
 * index 目标索引，如果越界则取最大值
 * animation 出于缓存考虑(其实是TODO😂)，目前不相邻的tab不会有动画
 */
- (void)moveToControllerAtIndex:(NSInteger)index
                      animation:(BOOL)animation;

// readwrite
@property (nonatomic, assign, readwrite) BOOL scrollEnable;
@property (nonatomic, assign, readonly)  BOOL isDragging;

#pragma mark - dataSource getter
//当前所在的索引，具体切换时机看最上面的注释
@property (nonatomic, assign, readonly) NSInteger currentIndex;

//只有缓存的才会返回，一般来说只有currentIndex所在的才有
- (UIViewController *)viewControllerAtIndex:(NSInteger)index;

///////////////////// dataSource setter /////////////////////
@property (nonatomic, weak) id<QHPageViewControllerDelegate>   delegate;

//dataSource和init的时候不一致会做一次删缓存刷新操作，建议init的时候传
@property (nonatomic, weak) id<QHPageViewControllerDataSource> dataSource;

///////////////////// DEPRECATED /////////////////////
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_UNAVAILABLE;
- (instancetype)initWithNibName:(NSString *)nibNameOrNil
                         bundle:(NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

@protocol  QHPageViewControllerDelegate <NSObject>

@optional
//具体切换时机看最上面的注释
- (void)pageViewController:(QHPageViewController *)pageViewController
        didUpdateIndexFrom:(NSInteger)formIndex
                   toIndex:(NSInteger)toIndex;

//拖拽状态改变
- (void)pageViewController:(QHPageViewController *)pageViewController
    draggeStatusDidChanged:(BOOL)isDragging;

//控制器已经稳定
- (void)pageViewController:(QHPageViewController *)pageViewController
                   currentIndex:(NSInteger)index;

@end

@protocol  QHPageViewControllerDataSource <NSObject>

@required

- (UIViewController *)pageViewController:(QHPageViewController *)pageViewController
                viewControllerForIndex:(NSInteger)index;

- (NSInteger)numberOfViewControllersForPageViewController:(QHPageViewController *)pageViewController;

@end



