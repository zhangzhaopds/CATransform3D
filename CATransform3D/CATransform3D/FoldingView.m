//
//  FoldingView.m
//  CATransform3D
//
//  Created by Scott on 16/2/23.
//  Copyright © 2016年 Scott. All rights reserved.
//

#import "FoldingView.h"
#import <CoreGraphics/CoreGraphics.h>

@interface FoldingView ()

@property (nonatomic, strong) UIImageView *imageViewForLeft;
@property (nonatomic, strong) UIImageView *imageViewForRight;

@property (nonatomic, strong) UIImageView *rightBackView;

@property (nonatomic, strong) CAGradientLayer *gradientForLeft;
@property (nonatomic, strong) CAGradientLayer *gradientForRight;

@property (nonatomic, assign) NSUInteger initialLocation;

@end


@implementation FoldingView

/** 从storyBoard 进入. */
- (void)awakeFromNib {
    
    [self createSubView];
}


/** 
 * 图片由两个UIImageView组成, 每个UIImageView显示图片的一半.
 */
- (void)createSubView {
    
    UIImage *image = [UIImage imageNamed:@"4.jpg"];
    
    self.imageViewForLeft = [[UIImageView alloc] init];
    self.imageViewForRight = [[UIImageView alloc] init];
    
    
    self.imageViewForLeft.userInteractionEnabled = YES;
    self.imageViewForRight.userInteractionEnabled = YES;
    
    
    // UIImageView的位置大小.
    self.imageViewForLeft.frame = CGRectMake(0, 0, CGRectGetWidth(self.bounds) / 2, CGRectGetHeight(self.bounds));
    
#pragma mark - 知识点1: CALayer属性 anchorPoint(锚点)
    /**
     * 每一个UIView内部都默认关联着一个CALayer, UIView有frame、bounds和center三个属性，CALayer也有类似的属性，分别为frame、bounds、position、anchorPoint。frame和bounds比较好理解，bounds可以视为x坐标和y坐标都为0的frame，那position、anchorPoint是什么呢？先看看两者的原型，可知都是CGPoint点。
     
     * @property CGPoint position
     * @property CGPoint anchorPoint
     *
     * anchorPoint 介绍:
     * 从一个例子开始入手吧，想象一下，把一张A4白纸用图钉订在书桌上，如果订得不是很紧的话，白纸就可以沿顺时针或逆时针方向围绕图钉旋转，这时候图钉就起着支点的作用。我们要解释的anchorPoint就相当于白纸上的图钉，它主要的作用就是用来作为变换的支点，旋转就是一种变换，类似的还有平移、缩放。
     
       继续扩展，很明显，白纸的旋转形态随图钉的位置不同而不同，图钉订在白纸的正中间与左上角时分别造就了两种旋转形态，这是由图钉（anchorPoint）的位置决定的。如何衡量图钉（anchorPoint）在白纸中的位置呢？在iOS中，anchorPoint点的值是用一种相对bounds的比例值来确定的，在白纸的左上角、右下角，anchorPoint分为为(0,0), (1, 1)，也就是说anchorPoint是在单元坐标空间(同时也是左手坐标系)中定义的。类似地，可以得出在白纸的中心点、左下角和右上角的anchorPoint为(0.5,0.5), (0,1), (1,0)。
     */
    // 设置右边ImageView的锚点
    self.imageViewForRight.layer.anchorPoint = CGPointMake(0, 0.5);
    
    self.imageViewForRight.frame = CGRectMake(CGRectGetMidX(self.bounds), 0, CGRectGetWidth(self.bounds) / 2, CGRectGetHeight(self.bounds));
    
    // 剪切图片. 每个ImageView显示照片的一半.
    self.imageViewForLeft.image = [self clipImageWithImage:image isLeftImage:YES];
    self.imageViewForRight.image = [self clipImageWithImage:image isLeftImage:NO];
    
    // 加到父视图.
    [self addSubview:self.imageViewForLeft];
    [self addSubview:self.imageViewForRight];
    
    
    // 添加圆边效果.
    self.imageViewForLeft.layer.mask = [self getCornerRidusMashWithIsLeft:YES rect:self.imageViewForLeft.bounds];
    
    self.imageViewForRight.layer.mask = [self getCornerRidusMashWithIsLeft:NO rect:self.imageViewForRight.bounds];
    
    
    self.rightBackView = [[UIImageView alloc] initWithFrame:self.imageViewForRight.bounds];
    
    // 设置高斯滤镜.
    self.rightBackView.image = [self getBlurAndReversalImage:[self clipImageWithImage:image isLeftImage:NO]];
    self.rightBackView.alpha = 0;
    [self.imageViewForRight addSubview:self.rightBackView];
    
    // 渐变颜色
    [self gradientLayer];
    
    // 手势
    self.imageViewForRight.layer.transform = [self getTransForm3DWithAngle:0];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self.imageViewForRight addGestureRecognizer:pan];

    
}

#pragma mark - 知识点2: CGImage
- (UIImage *)clipImageWithImage:(UIImage *)image isLeftImage:(BOOL)isLeft {
    
    CGRect imgRect = CGRectMake(0, 0, image.size.width / 2, image.size.height);
    
    if (!isLeft) {
        imgRect.origin.x = image.size.width / 2;
    }
    
    CGImageRef imgRef = CGImageCreateWithImageInRect(image.CGImage, imgRect);
    
    UIImage *clipImage = [UIImage imageWithCGImage:imgRef];
    
    return clipImage;
}


#pragma mark - 知识点3: CAShapeLayer, UIRectConner 
- (CAShapeLayer *)getCornerRidusMashWithIsLeft:(BOOL)isLeft rect:(CGRect)rect {
    
    //  创建CAShapeLayer对象.
    CAShapeLayer *layer = [CAShapeLayer layer];
    
    // 创建矩形圆角结构体
    UIRectCorner corner = isLeft ? UIRectCornerTopLeft | UIRectCornerBottomLeft : UIRectCornerTopRight | UIRectCornerBottomRight;
    
    // 通过贝塞尔曲线创建矩形圆角.
    layer.path = [UIBezierPath bezierPathWithRoundedRect:rect byRoundingCorners:corner cornerRadii:CGSizeMake(10, 10)].CGPath;
    
    return  layer;
}


#pragma mark - 知识点4: CIFilter (iOS 滤镜).
- (UIImage *)getBlurAndReversalImage:(UIImage *)image {
    
    CIContext *context = [CIContext contextWithOptions:nil];
    CIImage *inputImage = [CIImage imageWithCGImage:image.CGImage];
    
    // 高斯滤镜.
    CIFilter *filter = [CIFilter filterWithName:@"CIGaussianBlur"];
    
    [filter setValue:inputImage forKey:kCIInputImageKey];
    [filter setValue:@10.0 forKey:@"inputRadius"];
    
    CIImage *result = [filter valueForKey:kCIOutputImageKey];
    result = [result imageByApplyingTransform:CGAffineTransformMakeTranslation(-1, 1)];
    
    CGImageRef ref = [context createCGImage:result fromRect:[inputImage extent]];
    
    UIImage *returnImage = [UIImage imageWithCGImage:ref];
    
    CGImageRelease(ref);
    
    return returnImage;


}


#pragma mark - 知识点5: 渐变图层(CAGradientLayer)
- (void)gradientLayer {
    
    // 渐变颜色
    self.gradientForLeft = [CAGradientLayer layer];
    self.gradientForLeft.opacity = 0; /**< 不透明度. */
    self.gradientForLeft.colors = @[(id)[UIColor clearColor].CGColor, (id)[UIColor blackColor].CGColor];
    self.gradientForLeft.frame = self.imageViewForLeft.bounds;
    self.gradientForLeft.startPoint = CGPointMake(1, 1);
    self.gradientForLeft.startPoint = CGPointMake(0, 1);
    [self.imageViewForLeft.layer addSublayer:self.gradientForLeft];
    
    
    self.gradientForRight = [CAGradientLayer layer];
    self.gradientForRight.opacity = 0;
    self.gradientForRight.colors = @[(id)[UIColor clearColor].CGColor, (id)[UIColor blackColor].CGColor];
    self.gradientForRight.frame = self.imageViewForRight.bounds;
    self.gradientForRight.startPoint = CGPointMake(0, 1);
    self.gradientForRight.startPoint = CGPointMake(1, 1);
    [self.imageViewForRight.layer addSublayer:self.gradientForRight];
    
}

#pragma mark - 知识点6: CATransform3D
- (CATransform3D)getTransForm3DWithAngle:(CGFloat)angle {
    
    CATransform3D transform = CATransform3DIdentity;
    transform.m34 = 4.5 / 2000;
    transform = CATransform3DRotate(transform, angle, 0, 1, 0);
    return transform;
}


#pragma mark - other
- (void)handlePan:(UIPanGestureRecognizer *)pan {
    
    
    CGPoint location = [pan locationInView:self];
    if (pan.state == UIGestureRecognizerStateBegan) {
        self.initialLocation = location.x;
    }
    NSLog(@"y:%@",[self.imageViewForRight.layer valueForKeyPath:@"transform.rotation.y"]);
    NSLog(@"x:%@",[self.imageViewForRight.layer valueForKeyPath:@"transform.rotation.x"]);
    
    
    if ([[self.imageViewForRight.layer valueForKeyPath:@"transform.rotation.y"] floatValue] > -M_PI_2&&([[self.imageViewForRight.layer valueForKeyPath:@"transform.rotation.x"] floatValue] != 0)) {
        NSLog(@"------------%@",[self.imageViewForRight.layer valueForKeyPath:@"transform.rotation.y"]);
        self.rightBackView.alpha = 1;
        self.gradientForRight.opacity = 0;
        CGFloat opacity = (location.x-self.initialLocation)/(CGRectGetWidth(self.bounds)-self.initialLocation);
        self.gradientForLeft.opacity =fabs(opacity);
    }
    else if(([[self.imageViewForRight.layer valueForKeyPath:@"transform.rotation.y"] floatValue] > -M_PI_2)&&([[self.imageViewForRight.layer valueForKeyPath:@"transform.rotation.y"] floatValue]<0)&&([[self.imageViewForRight.layer valueForKeyPath:@"transform.rotation.x"] floatValue] == 0))
    {
        self.rightBackView.alpha = 0;
        CGFloat opacity = (location.x-self.initialLocation)/(CGRectGetWidth(self.bounds)-self.initialLocation);
        //self.rightShadowLayer.opacity = 0 ;
        self.gradientForRight.opacity =fabs(opacity)*0.5 ;
        self.gradientForLeft.opacity =fabs(opacity)*0.5;
    }
    if ([self isLocation:location inView:self]) {
        CGFloat conversioFactor = M_PI/(CGRectGetWidth(self.bounds)-self.initialLocation);
        self.imageViewForRight.layer.transform = [self getTransForm3DWithAngle:(location.x-self.initialLocation)*conversioFactor];
    }
    else
    {
        pan.enabled=NO;
        pan.enabled=YES;
    }
    if (pan.state == UIGestureRecognizerStateEnded||pan.state == UIGestureRecognizerStateCancelled) {
        ;
    }

}


- (BOOL)isLocation:(CGPoint)location inView:(UIView *)view{
    
    if ((location.x>0 && location.x<CGRectGetWidth(view.frame))&&(location.y>0&&location.y<CGRectGetHeight(view.frame))) {
        return YES;
    }
    else
    {
        return NO;
    }
}

@end
