//
//  VQRCodeController.h
//  QRCode
//
//  Created by Vols on 16/4/2.
//  Copyright © 2016年 Vols. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void (^QRCodeResultBlock)(NSString *result);

@interface VQRCodeController : UIViewController

@property (nonatomic, copy) QRCodeResultBlock QRCodeResult;

@end
