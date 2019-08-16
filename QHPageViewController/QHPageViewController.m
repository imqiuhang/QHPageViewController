//
//  QHPageViewController.m
//  
//
//  Created by imqiuhang on 2019/6/28.
//

#import "QHPageViewController.h"
#import <objc/runtime.h>

typedef NS_ENUM(NSUInteger, HTCMPageLifeStatus) {
    HTCMPageLifeStatusNone = 0,
    HTCMPageLifeStatusWillAppear,
    HTCMPageLifeStatusDidAppear,
    HTCMPageLifeStatusWillDisappear,
    HTCMPageLifeStatusDidDisappear
};

@interface UIViewController (QHPageViewController)

//用作缓存的下标
@property (nonatomic, strong) NSNumber *cmpage_index;

//用作主动调用的生命周期完整性检查
@property (nonatomic, assign) HTCMPageLifeStatus cmpage_lifeStaus;

@end

@implementation UIViewController (QHPageViewController)

- (NSNumber *)cmpage_index {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setCmpage_index:(NSNumber *)cmpage_index {
    objc_setAssociatedObject(self, @selector(cmpage_index), cmpage_index, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (HTCMPageLifeStatus)cmpage_lifeStaus {
    NSNumber *status = objc_getAssociatedObject(self, _cmd);
    if (status==nil) {
        return HTCMPageLifeStatusNone;
    }
    return status.integerValue;
}

- (void)setCmpage_lifeStaus:(HTCMPageLifeStatus)cmpage_lifeStaus {
    objc_setAssociatedObject(self, @selector(cmpage_lifeStaus), @(cmpage_lifeStaus), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end


@interface QHPageViewController ()<UIScrollViewDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
//目前其实只会存放一个当前的实例，兼容以后添加最大缓存需
@property (nonatomic, strong) NSMutableArray <UIViewController *> *cachedViewControllers;
@property (nonatomic, assign) NSInteger numberOfViewControllers;
//layout后会做一次update检查
@property (nonatomic, assign) CGSize lastScrollViewSize;
@property (nonatomic, strong) NSNumber *targetWaitMoveToIndex;

@end

@implementation QHPageViewController

- (instancetype)initWithOrientation:(QHPageViewControllerNavigationOrientation)orientation
                           delegate:(id<QHPageViewControllerDelegate>)delegate
                         dataSource:(id<QHPageViewControllerDataSource>)dataSource {
    
    if (self=[super initWithNibName:nil bundle:nil]) {
        
        _scrollEnable = YES;
        _targetWaitMoveToIndex = @(0);
        _numberOfViewControllers = 0;
        _orientation = orientation;
        _delegate    = delegate;
        _dataSource  = dataSource;
        _cachedViewControllers = [NSMutableArray array];
    }
    return self;
}

#pragma mark - lifeCycle
- (void)viewDidLoad {
    [super viewDidLoad];
    [self setup];
}

- (void)viewDidLayoutSubviews {
    
    [super viewDidLayoutSubviews];
    [self __reloadAndUpdateLastSizeIfNeed];
}

- (void)viewDidAppear:(BOOL)animated {
    
    [super viewDidAppear:animated];
    [self __reloadAndUpdateLastSizeIfNeed];
}

- (void)__reloadAndUpdateLastSizeIfNeed {
    
    if (!CGSizeEqualToSize(self.lastScrollViewSize, self.scrollView.frame.size)) {
        self.lastScrollViewSize = self.scrollView.frame.size;
        [self reload];
    }
}

#pragma mark - public control
- (void)setDataSource:(id<QHPageViewControllerDataSource>)dataSource {
    if (dataSource!=_dataSource) {
        _dataSource = dataSource;
        [self reloadWithCleanCache:YES];
    }
}

- (void)reload {
    [self reloadWithCleanCache:NO];
}

- (void)reloadWithCleanCache:(BOOL)cleanCache {
    
    if (!self.isViewLoaded) {
        return;
    }
    
    self.lastScrollViewSize = self.scrollView.frame.size;
    
    [self __updateDataSourceCount];
    
    //数据源为空 那么只能做一次清除操作了
    if(self.numberOfViewControllers<=0) {
        cleanCache = YES;
    }
    
    if (cleanCache) {
        [self __removeAllControllers];
    }
    
    if (self.targetWaitMoveToIndex!=nil) {
        [self moveToControllerAtIndex:self.targetWaitMoveToIndex.integerValue animation:NO];
        self.targetWaitMoveToIndex = nil;
    }
    
    // 当数据源变小了，且当前的current超出数据源大小,这里做了一次强制指向最大的index，是否需要？
    if(self.currentIndex>=self.numberOfViewControllers) {
        [self moveToControllerAtIndex:self.numberOfViewControllers-1 animation:NO];
    }
}

- (void)__updateDataSourceCount {
    
    NSInteger oldNumberOfViewControllers = self.numberOfViewControllers;
    
    [self checkAndThrowExceptionIfDataSourceInvalid];
    
    if (self.dataSource&&
        [self.dataSource respondsToSelector:@selector(numberOfViewControllersForPageViewController:)]) {
        self.numberOfViewControllers = [self.dataSource numberOfViewControllersForPageViewController:self];
    }else {
        self.numberOfViewControllers = 0;
    }
    
    if (self.numberOfViewControllers!=oldNumberOfViewControllers) {
        
        if (self.orientation==QHPageViewControllerNavigationOrientationHorizontal) {
            self.scrollView.contentSize = CGSizeMake(self.numberOfViewControllers*CGRectGetWidth(self.scrollView.frame), self.scrollView.contentSize.height);
        }else {
            self.scrollView.contentSize = CGSizeMake(self.scrollView.contentSize.width, self.numberOfViewControllers*CGRectGetHeight(self.scrollView.frame));
        }
    }
}

- (void)moveToControllerAtIndex:(NSInteger)index animation:(BOOL)animation {
    
    if (!self.viewLoaded) {
        self.targetWaitMoveToIndex = @(index);
        return;
    }
    
    //数据源为空 那真的没办反了
    if (self.numberOfViewControllers<=0) {
        return;
    }
    
    index = MAX(0, index);
    index = MIN(self.numberOfViewControllers-1, index);
    
    //TODO 不相邻的index 是否需要动画?
    if(ABS(self.currentIndex-index)>1) {
        animation = NO;
    }
    
    [self.scrollView setContentOffset:[self contentOffsetForIndex:index] animated:animation];
    
    if (!animation) {
        [self updateContentWithScroll:NO];
        [self handleCacheVcEndAppearanceTransition];
    }
}

- (void)setScrollEnable:(BOOL)scrollEnable {
    _scrollEnable = scrollEnable;
    self.scrollView.scrollEnabled = scrollEnable;
}

#pragma mark - public  getter
- (UIViewController *)viewControllerAtIndex:(NSInteger)index {
    
    __block UIViewController *tmpVc = nil;
    
    [self.cachedViewControllers enumerateObjectsUsingBlock:^(UIViewController * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.cmpage_index&&obj.cmpage_index.integerValue==index) {
            tmpVc = obj;
            *stop = YES;
        }
    }];
    return tmpVc;
}

- (BOOL)isDragging {
    return self.scrollView.isDragging;
}

#pragma mark - update
//hasScroll区分是否是滚动造成的update
- (void)updateContentWithScroll:(BOOL)hasScroll {
    
    NSMutableArray <NSNumber *> *inScreenIndexs = [NSMutableArray arrayWithCapacity:2];

    //后面可以优化一下，获取最匹配的index，取上下2个计算即可，时间比较急无法完全验证可靠性，所以先全遍历了
    for(int i=0;i<self.numberOfViewControllers;i++) {
        if([self isIndexInScreenWithIndex:i]) {
            [inScreenIndexs addObject:@(i)];
        }
    }
    
    //在屏幕内的尝试做一次添加操作
    for(NSNumber *index in inScreenIndexs) {
        [self addChildViewControllerIfNeedAtIndex:index.integerValue];
    }
    
    NSMutableArray <UIViewController *> *tmpNeedRemoveVcs = [NSMutableArray arrayWithCapacity:2];
    
    [self.cachedViewControllers enumerateObjectsUsingBlock:^(UIViewController * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        //不在屏幕内了做一次移除操作
        if (obj.cmpage_index==nil||![inScreenIndexs containsObject:obj.cmpage_index]){
            [tmpNeedRemoveVcs addObject:obj];
        }
    }];
    
    if (tmpNeedRemoveVcs.count) {
        [self.cachedViewControllers removeObjectsInArray:tmpNeedRemoveVcs];
    }
    
    [tmpNeedRemoveVcs enumerateObjectsUsingBlock:^(UIViewController * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self removeSubControllerWithVc:obj];
    }];
    
    //模拟UIPage的生命周期，滑动的时候 之前可见的VC会做一次WillDisappear的操作
    //inScreenIndexs<2说明在内容区外滑动，直接忽略
    if (hasScroll&&inScreenIndexs.count>=2) {
        for(UIViewController *vc in self.cachedViewControllers) {
            //HTCMPageLifeStatusDidAppear说明之前已经在屏幕里了，做一次将要消失的事务
            if (vc.cmpage_lifeStaus == HTCMPageLifeStatusDidAppear) {
                vc.cmpage_lifeStaus = HTCMPageLifeStatusWillDisappear;
                [vc beginAppearanceTransition:NO animated:YES];
            }
        }
    }

    NSInteger newCurrentIndex = self.currentIndex;
    //这里比较关键，为了模拟UIPageView的效果，如果当前index已经在屏幕了，那么不会重新调用切换的，只有切出去了才会去调用一次
    if (![inScreenIndexs containsObject:@(self.currentIndex)]) {
        newCurrentIndex = [self matchingIndexForOffset:self.scrollView.contentOffset];
    }
    
    if (self.currentIndex!=newCurrentIndex) {
        NSInteger oldIndex = self.currentIndex;
        _currentIndex = newCurrentIndex;
        if (self.delegate&&[self.delegate respondsToSelector:@selector(pageViewController:didUpdateIndexFrom:toIndex:)]) {
            [self.delegate pageViewController:self didUpdateIndexFrom:oldIndex toIndex:newCurrentIndex];
        }
    }
}

#pragma mark - scrollViewDelegate
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [self updateContentWithScroll:YES];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    //decelerate和scrollViewDidEndDecelerating互斥
    if (!decelerate) {
        [self handleCacheVcEndAppearanceTransition];
    }
    if (self.delegate&&[self.delegate respondsToSelector:@selector(pageViewController:draggeStatusDidChanged:)]) {
        [self.delegate pageViewController:self draggeStatusDidChanged:NO];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self handleCacheVcEndAppearanceTransition];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    if (!scrollView.dragging) {
        [self handleCacheVcEndAppearanceTransition];
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if (self.delegate&&[self.delegate respondsToSelector:@selector(pageViewController:draggeStatusDidChanged:)]) {
        [self.delegate pageViewController:self draggeStatusDidChanged:YES];
    }
}

///操作结束的时候将当前index所在的VC唤起一次DidAppear，disAppear不会操作，因为滚出不可见区域会释放掉，已经做了操作
- (void)handleCacheVcEndAppearanceTransition {
    
    UIViewController *vc = [self viewControllerAtIndex:self.currentIndex];
    if(!vc) {
        return;
    }
    
    //只有在will状态说明欠一次end操作
    if(vc.cmpage_lifeStaus==HTCMPageLifeStatusWillAppear||
       vc.cmpage_lifeStaus==HTCMPageLifeStatusWillDisappear) {
    /* 模拟UIPage，在滑动后原来的VC会触发一次willDisappare,停止以后触发WillAppear和didAppear
     * 所以这里先将状态先切会到WillAppear，这样endAppearanceTransition之后调用的是didAppear
     * 否则endAppearanceTransition调用的是didDisappear*/
        if (vc.cmpage_lifeStaus==HTCMPageLifeStatusWillDisappear) {
            [vc beginAppearanceTransition:YES animated:NO];
        }
        [vc endAppearanceTransition];
        vc.cmpage_lifeStaus = HTCMPageLifeStatusDidAppear;
    }
}

#pragma mark - private getter
- (BOOL)isIndexInScreenWithIndex:(NSInteger)index {
  
    CGFloat realCurrentOffset = [self realOffsetValueForOffset:self.scrollView.contentOffset];
    CGFloat contentWidth = [self realContentWidth];
    CGFloat indexOffset = [self realOffsetValueForOffset:[self contentOffsetForIndex:index]];
    
    return (fabs(realCurrentOffset - indexOffset) < contentWidth);
}

- (NSInteger)matchingIndexForOffset:(CGPoint)offset {
    
    NSInteger result = ([self realOffsetValueForOffset:offset] + (1.5f * [self realContentWidth])) / [self realContentWidth];
    result =  (result - 1);
    result = MIN(self.numberOfViewControllers -1, result);
    result = MAX(0, result);
    return  result;
}

- (CGFloat)realOffsetValueForOffset:(CGPoint)offset {
    return (self.orientation==QHPageViewControllerNavigationOrientationHorizontal)?offset.x:offset.y;
}

- (CGFloat)realContentWidth {
    return  (self.orientation==QHPageViewControllerNavigationOrientationHorizontal)?CGRectGetWidth(self.scrollView.frame):CGRectGetHeight(self.scrollView.frame);
}

- (CGPoint)contentOffsetForIndex:(NSInteger)index {
    
    index = MIN(self.numberOfViewControllers -1, index);
    index = MAX(0, index);
    
    if (self.orientation==QHPageViewControllerNavigationOrientationHorizontal) {
        return CGPointMake(index*CGRectGetWidth(self.scrollView.frame), 0);
    }else {
        return CGPointMake(0,index*CGRectGetHeight(self.scrollView.frame));
    }
}

#pragma mark - private control
- (void)addChildViewControllerIfNeedAtIndex:(NSInteger)index {
    
    if (index<0||index>=self.numberOfViewControllers) {
        return;
    }
    
    __block UIViewController *vc = nil;
    [self.cachedViewControllers enumerateObjectsUsingBlock:^(UIViewController * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        if (obj.cmpage_index!=nil&&
            obj.cmpage_index.integerValue==index) {
            
            vc = obj;
            *stop = YES;
        }
    }];
    
    if (!vc) {
        [self checkAndThrowExceptionIfDataSourceInvalid];
        if (self.dataSource&&[self.dataSource respondsToSelector:@selector(pageViewController:viewControllerForIndex:)]) {
            vc = [self.dataSource pageViewController:self viewControllerForIndex:index];
            vc.cmpage_index = @(index);
        }
    }
    
    if (!vc) {
        return;
    }
    
    CGPoint offset = [self contentOffsetForIndex:index];
    
    if (![self.cachedViewControllers containsObject:vc]) {
        [self.cachedViewControllers addObject:vc];
    }
    
    if (!vc.parentViewController) {
        
        vc.cmpage_lifeStaus = HTCMPageLifeStatusWillAppear;
        [vc beginAppearanceTransition:YES animated:NO];
        [self addChildViewController:vc];
        [self.scrollView addSubview:vc.view];
        vc.view.frame = CGRectMake(offset.x, offset.y, CGRectGetWidth(self.scrollView.frame), CGRectGetHeight(self.scrollView.frame));
        vc.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [vc didMoveToParentViewController:self];
        //这里不再调用，延迟到scroll结束调用
//        [vc endAppearanceTransition];
    }else {
        [self.scrollView addSubview:vc.view];
        vc.view.frame = CGRectMake(offset.x, offset.y, CGRectGetWidth(self.scrollView.frame), CGRectGetHeight(self.scrollView.frame));
        vc.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
}

- (void)__removeAllControllers {
    
    [self.cachedViewControllers enumerateObjectsUsingBlock:^(UIViewController * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self removeSubControllerWithVc:obj];
    }];
    
    [self.cachedViewControllers removeAllObjects];
}

- (void)removeSubControllerWithVc:(UIViewController *)vc {
    
    if (!vc) {
        return;
    }
    if (vc.parentViewController) {
        
        [vc willMoveToParentViewController:nil];
        [vc beginAppearanceTransition:NO animated:NO];
        vc.cmpage_lifeStaus = HTCMPageLifeStatusWillDisappear;
        [vc.view removeFromSuperview];
        [vc removeFromParentViewController];
        [vc endAppearanceTransition];
        vc.cmpage_lifeStaus = HTCMPageLifeStatusDidDisappear;
    }
}

- (void)checkAndThrowExceptionIfDataSourceInvalid {
    
    NSParameterAssert(self.dataSource);
    NSAssert([self.dataSource respondsToSelector:@selector(numberOfViewControllersForPageViewController:)], @"dataSource must return numberOfViewControllersForPageViewController");
    NSAssert([self.dataSource respondsToSelector:@selector(pageViewController:viewControllerForIndex:)], @"dataSource must return viewControllerAtIndex:");
}

#pragma mark - setup
- (void)setup {
    
    self.scrollView = ({
        
        UIScrollView *view = [[UIScrollView alloc] initWithFrame:self.view.bounds];
        [self.view addSubview:view];
        view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        view.bounces = YES;
        view.scrollsToTop = NO;
        view.showsVerticalScrollIndicator = NO;
        view.showsHorizontalScrollIndicator = NO;
        view.pagingEnabled = YES;
        view.clipsToBounds = YES;
        view.delegate = self;
        if (@available(iOS 11.0, *)) {
            view.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        }
        view;
    });
}

@end
