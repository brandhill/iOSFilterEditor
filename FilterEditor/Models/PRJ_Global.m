//
//  PRJ_Global.m
//  IOSNoCrop
//
//  Created by rcplatform on 14-4-18.
//  Copyright (c) 2014年 rcplatformhk. All rights reserved.
//

#import "PRJ_Global.h"
#import "UIImage+SubImage.h"
#import "MobClick.h"
#import "CMethods.h"

@implementation PRJ_Global

@synthesize originalImage = _originalImage;
@synthesize compressionImage = _compressionImage;

+ (void)load
{

}

static PRJ_Global *_glo = nil;

+ (PRJ_Global *)shareStance
{
    if (_glo == nil) {
        _glo = [[PRJ_Global alloc]init];
        _glo.canShowPopUp = YES;
    }
    return _glo;
}

- (id)init{
    if(self = [super init]){
        
        self.outputResolutionType = (OutputResolutionType)[[NSUserDefaults standardUserDefaults] integerForKey:UDKEY_OutputResolutionType];
    }
    return self;
}

- (void)setOriginalImage:(UIImage *)originalImage{

    //设置原始图片的同时，获取压缩后的图片
    float multiple = 0.0 ,newHeight = 0.0 ,newWidth = 0.0;
    if (originalImage.size.height >= originalImage.size.width) {
        multiple = originalImage.size.height/1080;
        newHeight = 1080;
        newWidth = originalImage.size.width/multiple;
    }else{
        multiple = originalImage.size.width/1080;
        newWidth = 1080;
        newHeight = originalImage.size.height/multiple;
    }
    
    UIImage *scaleImage = [[UIImage alloc]initWithData:[UIImage createThumbImage:originalImage size:CGSizeMake(newWidth, newHeight) percent:0.8]];
    
    _originalImage = [scaleImage rescaleImageToSize:scaleImage.size];
    _compressionImage = [scaleImage rescaleImageToSize:scaleImage.size];
}

- (void)setBoxCount:(int)boxCount{
    _boxCount = boxCount;
    
    // 2 3  ==> 1.5
    // 4 5 ==> 1.4
    // 6 7 ==> 1.3
    // 8 9 == > 1.2
    
    _compScale = 1.5;

    NSString *device = doDevicePlatform();
    if([device rangeOfString:@"iPod"].length ||
       [device rangeOfString:@"iPhone3"].length ||
       [device rangeOfString:@"iPhone4"].length ||
       [device rangeOfString:@"iPhone 4"].length){
        
        switch (_boxCount) {
                
            case 4:
            case 5:
                _compScale = 1.4;
                break;
            case 6:
            case 7:
                _compScale = 1.3;
                break;
            case 8:
            case 9:
                _compScale = 1.2;
                break;
                
            default:
                _compScale = 1.5;
                break;
        }
    }
}


+ (void)event:(NSString *)desc label:(NSString *)eventID{
    
    //友盟
    [MobClick event:eventID label:desc];
}

- (NSString *)getCurrentOutputResolutionStr{
    return [self getOutputResolutionStrWithType:_outputResolutionType];
}

- (NSString *)getOutputResolutionStrWithType:(OutputResolutionType)type{
    switch (type) {
        case kOutputResolutionType1080_1080:
            return LocalizedString(@"standard", nil);
        case kOutputResolutionType1660_1660:
            return LocalizedString(@"HD", nil);
        default:
            return nil;
//        case kOutputResolutionType1080_1080:
//            return @"1080*1080";
//        case kOutputResolutionType1660_1660:
//            return @"1660*1660";
//        case kOutputResolutionType2160_2160:
//            return @"2160*2160";
//        default:
//            return nil;
    }
}

@end