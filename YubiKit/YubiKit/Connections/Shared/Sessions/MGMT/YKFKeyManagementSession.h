//
//  YKFKeyManagementService.h
//  YubiKit
//
//  Created by Irina Makhalova on 2/4/20.
//  Copyright © 2020 Yubico. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "YKFKeyRawCommandSession.h"
#import "YKFKeyManagementReadConfigurationResponse.h"

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name Management Service Response Blocks
 * ---------------------------------------------------------------------------------------------------------------------
 */
/*!
 @abstract
    Response block for [readConfigurationWithCompletion:completion:] which provides the result for the execution
    of the Calculate request.
 
 @param response
    The response of the request when it was successful. In case of error this parameter is nil.

 @param error
    In case of a failed request this parameter contains the error. If the request was successful this
    parameter is nil.
 */
typedef void (^YKFKeyManagementSessionReadCompletionBlock)
    (YKFKeyManagementReadConfigurationResponse* _Nullable response, NSError* _Nullable error);



typedef void (^YKFKeyManagementSessionWriteCompletionBlock) (NSError* _Nullable error);


NS_ASSUME_NONNULL_BEGIN

/*!
@abstract
   Defines the interface for YKFKeyManagementSessionProtocol.
*/
@protocol YKFKeyManagementSessionProtocol<NSObject>

/*!
@method readConfigurationWithCompletion:

@abstract
    Reads configuration from YubiKey (what interfaces/applications are enabled and supported)

@param completion
   The response block which is executed after the request was processed by the key. The completion block
   will be executed on a background thread.

@note:
   This method is thread safe and can be invoked from any thread (main or a background thread).
*/
- (void)readConfigurationWithCompletion:(YKFKeyManagementSessionReadCompletionBlock)completion;

/*!
@method writeConfiguration:completion

@abstract
    Writes configuration to YubiKey (allos to enable and disable applications on YubiKey)

@param configuration
    The configurations that represent information on which interfaces/applications need to be enabled

@param reboot
    The device reboots after setting configuration.
 
@param completion
    The response block which is executed after the request was processed by the key. The completion block
    will be executed on a background thread.

@note:
   This method is thread safe and can be invoked from any thread (main or a background thread).
*/
- (void)writeConfiguration:(YKFManagementInterfaceConfiguration*) configuration reboot: (BOOL) reboot completion: (nonnull YKFKeyManagementSessionWriteCompletionBlock) completion;

@end

NS_ASSUME_NONNULL_END

NS_ASSUME_NONNULL_BEGIN

@interface YKFKeyManagementSession : NSObject<YKFKeyManagementSessionProtocol>

- (nonnull instancetype)init NS_UNAVAILABLE;


@end

NS_ASSUME_NONNULL_END
