#import "KeyfileValidator.h"
#import "Constants.h"

static void SetKeyfileValidationError(NSError **error, NSInteger code, NSString *message)
{
    if (error) {
        *error = [NSError errorWithDomain:@"VSCOKeys.Keyfile"
                                     code:code
                                 userInfo:@{NSLocalizedDescriptionKey: message}];
    }
}

static NSString *NumericString(id value)
{
    if (![value respondsToSelector:@selector(description)]) return nil;
    NSString *string = [value description];
    NSCharacterSet *nonDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    if (string.length == 0 || [string rangeOfCharacterFromSet:nonDigits].location != NSNotFound) return nil;
    return [NSString stringWithFormat:@"%llu", [string longLongValue]];
}

BOOL VSCOValidateKeyfile(NSDictionary *keyfile, NSError **error)
{
    if (error) *error = nil;
    if (![keyfile isKindOfClass:[NSDictionary class]]) {
        SetKeyfileValidationError(error, 2, @"The layout must be a dictionary.");
        return NO;
    }

    NSString *modeKey = NumericString([keyfile objectForKey:KEYFILE_MODEKEY_NODENAME]);
    NSArray *keys = [keyfile objectForKey:KEYFILE_KEYS_NODENAME];
    if (!modeKey || ![keys isKindOfClass:[NSArray class]]) {
        SetKeyfileValidationError(error, 2, @"The layout must contain a numeric mode key and a bindings array.");
        return NO;
    }

    NSMutableSet *bindingIdentities = [NSMutableSet set];
    for (id binding in keys) {
        if (![binding isKindOfClass:[NSDictionary class]]) {
            SetKeyfileValidationError(error, 2, @"Each binding must be a dictionary.");
            return NO;
        }

        NSString *key = NumericString([binding objectForKey:KEYFILE_KEY_NODENAME]);
        NSString *modifier = NumericString([binding objectForKey:KEYFILE_MODIFIERS_NODENAME]);
        NSInteger modifierMask = [modifier integerValue];
        id adjustments = [binding objectForKey:KEYFILE_ADJUSTMENTS_NODENAME];
        if (!key || !modifier || modifierMask > 15 ||
            ![adjustments isKindOfClass:[NSDictionary class]] || [adjustments count] == 0) {
            SetKeyfileValidationError(error, 2, @"Each binding needs a numeric keycode, a modifier mask from 0 to 15, and at least one action.");
            return NO;
        }

        NSString *identity = [NSString stringWithFormat:@"%@:%ld", key, (long)modifierMask];
        if ([bindingIdentities containsObject:identity]) {
            SetKeyfileValidationError(error, 3, [NSString stringWithFormat:@"Keycode %@ has more than one binding for modifier mask %@.", key, modifier]);
            return NO;
        }
        [bindingIdentities addObject:identity];

        if ([key isEqualToString:modeKey] && modifierMask == 0) {
            SetKeyfileValidationError(error, 4, [NSString stringWithFormat:@"Keycode %@ is the mode-toggle key and cannot also have an unmodified binding.", key]);
            return NO;
        }

        for (id action in adjustments) {
            id value = [adjustments objectForKey:action];
            if (![action isKindOfClass:[NSString class]] || !value || value == [NSNull null]) {
                SetKeyfileValidationError(error, 2, @"Each binding action must have a supported name and value.");
                return NO;
            }
            if ([action isEqualToString:KEYFILE_ADJUSTMENT_REMAP_NODENAME]) {
                id targetKey = [value isKindOfClass:[NSDictionary class]] ? [value objectForKey:KEYFILE_KEY_NODENAME] : value;
                id targetModifier = [value isKindOfClass:[NSDictionary class]] ? [value objectForKey:KEYFILE_MODIFIERS_NODENAME] : @"0";
                NSString *remapKey = NumericString(targetKey);
                NSString *remapModifier = NumericString(targetModifier);
                if (!remapKey || !remapModifier || [remapModifier integerValue] > 15) {
                    SetKeyfileValidationError(error, 2, @"A remap needs a numeric target keycode and a modifier mask from 0 to 15.");
                    return NO;
                }
            } else if ([action isEqualToString:@"_SetPreset"]) {
                NSString *preset = [value isKindOfClass:[NSString class]] ? [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] : @"";
                if (preset.length == 0) {
                    SetKeyfileValidationError(error, 2, @"Choose an available preset or enter a preset name before saving.");
                    return NO;
                }
            } else if (![value isKindOfClass:[NSString class]] && ![value isKindOfClass:[NSNumber class]]) {
                SetKeyfileValidationError(error, 2, @"Action values must be strings or numbers.");
                return NO;
            }
        }
    }

    return YES;
}
