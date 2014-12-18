//
//  EditViewController.m
//  FilterGrid
//
//  Created by herui on 4/9/14.
//  Copyright (c) 2014年 rcplatform. All rights reserved.
//

#import "EditViewController.h"
#import "UIImage+SubImage.h"
#import "NCVideoCamera.h"
#import "UIButton+helper.h"
#import "ShareViewController.h"
#import "PRJ_Global.h"
#import "CMethods.h"
#import "IS_Tools.h"
#import "ImageEditView.h"

@interface EditViewController () <IFVideoCameraDelegate,ImageEditViewDelegate,
                                     UIAlertViewDelegate>
{
    NSMutableArray *_patternImages;
    NCVideoCamera *_videoCamera;
    BOOL _isShowTemplateNav;
    TemplateType _templateType;
    //用于adjust image时使用,（在滤镜效果的基础上再作调整）
    NSMutableArray *_filterImages;
    __block bool _filtering;
    ImageEditView *_imageEditView;
    GPUImageView *captureView;
    NCFilterType filter_type;
    float lastValue;
    UIImageView *origin_imageView;
}

@property (nonatomic, strong) TemplatModel *templateModel;

@end

@implementation EditViewController

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    hideLoadingView();
    [self.navigationController setNavigationBarHidden:YES animated:YES];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = colorWithHexString(@"#2f2f2f");
    
    CGFloat imageEditViewH = 130;
    CGFloat imageEditViewY = kWinSize.height;
    CGFloat imageEditViewW = kWinSize.width;
    
    _imageEditView = [[ImageEditView alloc] initWithFrame:CGRectMake(0, imageEditViewY, imageEditViewW, imageEditViewH)];
    _imageEditView.delegate = self;
    [self.view addSubview:_imageEditView];

    [_imageEditView hideFilterIntensitySliderView];
    [IS_Tools ViewAnimation:_imageEditView withFrame:CGRectMake(0, imageEditViewY - imageEditViewH, imageEditViewW, imageEditViewH)];
 
    float height = ScreenHeight - imageEditViewH - kNavBarH;
    
    captureView = [[GPUImageView alloc] initWithFrame:CGRectMake(0, kNavBarH, windowWidth(), height)];
    captureView.center = CGPointMake(windowWidth()/2.f,kNavBarH + height/2.f);
    captureView.fillMode = kGPUImageFillModePreserveAspectRatio;
    [self.view addSubview:captureView];
    
    origin_imageView = [[UIImageView alloc] initWithFrame:captureView.frame];
    origin_imageView.hidden = YES;
    origin_imageView.contentMode = UIViewContentModeScaleAspectFit;
    origin_imageView.image = self.srcImage;
    [self.view addSubview:origin_imageView];
    
    //滤镜相关
    _videoCamera = [[NCVideoCamera alloc] initWithImage:[PRJ_Global shareStance].compressionImage andOutputView:captureView];
    _videoCamera.photoDelegate = self;
    _videoCamera.stillCameraDelegate = self;
    [_videoCamera switchFilterType:0 value:1.f];
    
    UIButton *ab_btn = [UIButton buttonWithType:UIButtonTypeCustom];
    [ab_btn setFrame:CGRectMake(windowWidth() - 44.5f, windowHeight() - 167.f, 44.5f, 37)];
    [ab_btn setImage:[UIImage imageNamed:@"fe_btn_AB_normal"] forState:UIControlStateNormal];
    [ab_btn setImage:[UIImage imageNamed:@"fe_btn_AB_normal"] forState:UIControlStateHighlighted];
    [ab_btn addTarget:self action:@selector(abbtnClickInside) forControlEvents:UIControlEventTouchDown];
    [ab_btn addTarget:self action:@selector(abbtnClickOutside) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:ab_btn];
    
    //nav
    CGFloat itemWH = kNavBarH;
    //顶部确定取消按钮、底部弹模板界面按钮
    UIButton *topConfirmBtn = [[UIButton alloc]initWithFrame:CGRectMake(0, 0, itemWH, itemWH)];
    [self.view addSubview:topConfirmBtn];
    [topConfirmBtn setImage:[UIImage imageNamed:@"fe_btn_share_pressed"] forState:UIControlStateHighlighted];
    [topConfirmBtn setImage:[UIImage imageNamed:@"fe_btn_share_normal"] forState:UIControlStateNormal];
    topConfirmBtn.center = CGPointMake(kWinSize.width - (itemWH * 0.5)-10, (itemWH * 0.5));
    [topConfirmBtn addTarget:self action:@selector(confirmBtnOnClick) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *topCancelBtn = [[UIButton alloc]initWithFrame:CGRectMake(0, 0, itemWH, itemWH)];
    [self.view addSubview:topCancelBtn];
    [topCancelBtn setImage:[UIImage imageNamed:@"fe_btn_back_pressed"] forState:UIControlStateHighlighted];
    [topCancelBtn setImage:[UIImage imageNamed:@"fe_btn_back_normal"] forState:UIControlStateNormal];
    topCancelBtn.center = CGPointMake(10+(itemWH * 0.5), (itemWH * 0.5));
    [topCancelBtn addTarget:self action:@selector(cancelBtnOnClick) forControlEvents:UIControlEventTouchUpInside];

    //注册通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(getTheBestImage) name:NNKEY_GETTHEBESTIMAGE object:nil];
}

- (void)abbtnClickInside
{
    origin_imageView.hidden = NO;
}

- (void)abbtnClickOutside
{
    origin_imageView.hidden = YES;
}

- (void)leftBarButtonItemClick
{
    [self.navigationController setNavigationBarHidden:YES animated:YES];
}

#pragma mark - 界面仨按钮点击动作
- (void)confirmBtnOnClick
{
    [PRJ_Global event:@"edit_done" label:@"Edit"];    
    //弹分享界面
    ShareViewController *shareVC = [[ShareViewController alloc] initWithNibName:@"ShareViewController" bundle:nil];
    shareVC.aspectRatio = _aspectRatio;
    [self.navigationController pushViewController:shareVC animated:YES];
}

- (void)cancelBtnOnClick
{
    [PRJ_Global event:@"edit_cancel" label:@"Edit"];
    UIAlertView *alert = [[UIAlertView alloc]initWithTitle:nil message:LocalizedString(@"alert_quit_edit", nil) delegate:self cancelButtonTitle:LocalizedString(@"edit_quit", nil) otherButtonTitles:LocalizedString(@"edit_continue", nil), nil];
    alert.tag = 100;
    [alert show];
}

#pragma mark - IFVideoCameraDelegate
- (void)videoCameraResultImage:(NSArray *)array
{
    UIImage *filter_image = array.firstObject;
    [PRJ_Global shareStance].compressionImage = filter_image;
}

- (void)stillCameraResultImage:(UIImage *)image
{
    NSLog(@"result");
}

#pragma mark - UIAlertViewDelegate
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    
    if (alertView.tag == 100)//退出编辑
    {
        if (buttonIndex == 0) {
            [self.navigationController popToRootViewControllerAnimated:YES];
        }
    }
    
    if(!buttonIndex)    return;
    //解锁模板时弹框
    
    switch (alertView.tag) {
        case kTemplateTypeGrid:
        {
            //解锁评价
            [PRJ_Global event:@"choosetemplate_rate_unlock" label:@"ChooseTemplate"];
            
            //跳评论
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:kAppStoreScoreURL]];
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:UDKEY_ReviewUnLock];
            
            //关闭评论提醒
            [[NSUserDefaults standardUserDefaults] setObject:@(-1) forKey:UDKEY_ShareCount];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
            break;
            
        case kTemplateTypeShape:
        {
            //解锁分享
            [PRJ_Global event:@"choosetemplate_share_unlock" label:@"ChooseTemplate"];
            
            //弹分享
            NSString *shareContent = @"需要分享的内容";
            NSArray *activityItems = @[shareContent];
            UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
            
            activityVC.completionHandler = ^(NSString *activityType,BOOL completed)
            {
                //分享成功则解锁
                if(completed)
                {
                    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:UDKEY_ShareUnLock];
                    [[NSNotificationCenter defaultCenter] postNotificationName:UNLOCK_BW object:[NSNumber numberWithInteger:5]];
                }
                
                UIView *banner = [PRJ_Global shareStance].bannerView;
                [[UIApplication sharedApplication].keyWindow addSubview:banner];
            };
            
            [self presentViewController:activityVC animated:YES completion:nil];
        }
            break;
            
        default:
            break;
    }
}

#pragma mark - 获取最终图片
- (void)getTheBestImage
{
    @autoreleasepool
    {
        //计算outputSize
        CGSize outputSize = CGSizeZero;
        switch ([PRJ_Global shareStance].outputResolutionType)
        {
            case kOutputResolutionType1080_1080:
            {
                switch (_aspectRatio) {
                    case kAspectRatioFree:
                        outputSize = CGSizeMake(1080 * [PRJ_Global shareStance].freeScale, 1080);
                        break;
                        
                    case kAspectRatio1_1:
                        outputSize = CGSizeMake(1080, 1080);
                        break;
                        
                    case kAspectRatio2_3:
                        outputSize = CGSizeMake(720, 1080);
                        break;
                        
                    case kAspectRatio3_2:
                        outputSize = CGSizeMake(1080, 720);
                        break;
                        
                    case kAspectRatio3_4:
                        outputSize = CGSizeMake(810, 1080);
                        break;
                        
                    case kAspectRatio4_3:
                        outputSize = CGSizeMake(1080, 810);
                        break;
                        
                    case kAspectRatio9_16:
                        outputSize = CGSizeMake(607, 1080);
                        break;
                        
                    case kAspectRatio16_9:
                        outputSize = CGSizeMake(1080, 607);
                        break;
                    default:
                        break;
                }
            }
                break;
            case kOutputResolutionType3240_3240:
            {
                switch (_aspectRatio)
                {
                    case kAspectRatioFree:
                        outputSize = CGSizeMake(3240 * [PRJ_Global shareStance].freeScale , 3240);
                        break;
                        
                    case kAspectRatio1_1:
                        outputSize = CGSizeMake(3240, 3240);
                        break;
                        
                    case kAspectRatio2_3:
                        outputSize = CGSizeMake(2160, 3240);
                        break;
                        
                    case kAspectRatio3_2:
                        outputSize = CGSizeMake(3240, 2160);
                        break;
                        
                    case kAspectRatio3_4:
                        outputSize = CGSizeMake(2430, 3240);
                        break;
                        
                    case kAspectRatio4_3:
                        outputSize = CGSizeMake(3240, 2430);
                        break;
                        
                    case kAspectRatio9_16:
                        outputSize = CGSizeMake(1822, 3240);
                        break;
                        
                    case kAspectRatio16_9:
                        outputSize = CGSizeMake(3240, 1822);
                        break;

                    default:
                        break;
                }
            }
                break;
            default:
                break;
        }
        
        CGSize contextSize = CGSizeMake([PRJ_Global shareStance].compressionImage.size.width, [PRJ_Global shareStance].compressionImage.size.height);
        UIGraphicsBeginImageContextWithOptions(contextSize, YES, 1.0);

        [[PRJ_Global shareStance].compressionImage drawInRect:CGRectMake(0, 0, contextSize.width, contextSize.height)];
        
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        //去黑框
        {
            CGFloat scaleW = 1;
            CGFloat scaleH = 1;
            
            switch (_aspectRatio)
            {
                case kAspectRatioFree:
                    scaleW = [PRJ_Global shareStance].freeScale;
                    scaleH = 1;
                    break;
                    
                case kAspectRatio1_1:
                    break;
                  
                case kAspectRatio2_3:
                    scaleW = 2;
                    scaleH = 3;
                    break;
                    
                case kAspectRatio3_2:
                    scaleW = 3;
                    scaleH = 2;
                    break;
                    
                case kAspectRatio3_4:
                    scaleW = 3;
                    scaleH = 4;
                    break;
                    
                case kAspectRatio4_3:
                    scaleW = 4;
                    scaleH = 3;
                    break;
                    
                case kAspectRatio9_16:
                    scaleW = 9;
                    scaleH = 16;
                    break;
                    
                case kAspectRatio16_9:
                    scaleW = 16;
                    scaleH = 9;
                    break;
  
                default:
                    break;
            }
            
            CGFloat w = image.size.width;
            CGFloat h = image.size.height;
            if(scaleW > scaleH)
            {
                h = w / (scaleW / scaleH);
            }
            else
            {
                w = h * (scaleW / scaleH);
            }
            CGFloat x = (image.size.width - w ) * 0.5;
            CGFloat y = (image.size.height - h ) * 0.5;
            image = [image subImageWithRect:CGRectMake(x, y, w - 1, h)];
        }
        
        //指定像素
        image = [image rescaleImageToSize:outputSize];
        [PRJ_Global shareStance].theBestImage = image;
    }
}

- (void)imageEditViewGropName:(NSString *)name
{
    NSString *msg = LocalizedString(@"share_unlock_shape", nil);
    NSString *btnTitle = LocalizedString(@"immediately_share", nil);
    NSString *eventSubtitle = @"share";
    
    NSString *event = [NSString stringWithFormat:@"choosetemplate_%@", eventSubtitle];
    [PRJ_Global event:event label:@"ChooseTemplate"];
    
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil
                                                        message:msg
                                                       delegate:self
                                              cancelButtonTitle:LocalizedString(@"cancel", nil)
                                              otherButtonTitles:btnTitle, nil];
    alertView.tag = kTemplateTypeShape;
    [alertView show];
}

- (void)imageEditView:(ImageEditView *)imageEditView ChangeFilterId:(NSInteger)filterId
{
    NSString *fileName = [NSString stringWithFormat:@"com_rcplatform_filter_config_%ld",(long)filterId];
    NSString *plistPath = [[NSBundle mainBundle] pathForResource:fileName ofType:@"plist"];
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] initWithContentsOfFile:plistPath];
    
    NSArray *keyArray = [dictionary allKeys];
    if ([keyArray containsObject:@"progressConfig"])
    {
        NSDictionary *dic = [dictionary objectForKey:@"progressConfig"];
        NSArray *keys = [dic allKeys];
        if ([keys containsObject:@"defaultProgress"])
        {
            float defaultProgress = [[dic objectForKey:@"defaultProgress"]integerValue]/100.0;
            float starProgress = [[dic objectForKey:@"startProgress"]integerValue]/100.0;
            float endProgress = [[dic objectForKey:@"endProgress"]integerValue]/100.0;
            lastValue = defaultProgress;
            filter_type = (NCFilterType)filterId;
            _imageEditView.starValue = starProgress;
            _imageEditView.endValue = endProgress;
            [_videoCamera switchFilterType:filter_type value:defaultProgress];
        }
    }
}

-(void)imageEditView:(ImageEditView *)imageEditView ChangeFilterIntensity:(CGFloat)intensity WithFilterId:(NSInteger)filterId
{
    [_videoCamera updateFilterParmas:intensity];
}

- (void)imageEditView:(ImageEditView *)imageEditView AdjustImageWithAdjustImageParam:(AdjustImageParam)adjustImageParam
{
    
}

- (void)imageEditViewConfirm:(ImageEditView *)imageEditView
{
    CGFloat imageEditViewH = 100;
    CGFloat imageEditViewY = kWinSize.height;
    CGFloat imageEditViewW = kWinSize.width;
    [IS_Tools ViewAnimation:_imageEditView withFrame:CGRectMake(0, imageEditViewY, imageEditViewW, imageEditViewH)];
}

- (void)imageEditViewRecover:(BOOL)recover
{
    [_videoCamera updateFilterParmas:lastValue];
}

- (void)dealloc
{
    NSLog(@"%s - dealloc", object_getClassName(self));
}

@end
