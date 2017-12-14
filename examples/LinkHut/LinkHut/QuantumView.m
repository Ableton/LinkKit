// Copyright: 2016, Ableton AG, Berlin. All rights reserved.

#import "QuantumView.h"


static const CGFloat kSpacing = 3;


@implementation QuantumView {
    NSMutableArray *_tiles;
    Float64 _quantum;
    BOOL _isPlaying;
    UIColor *_backgroundColor;
    UIColor *_activeColor;
    UIColor *_activeBeginColor;
    UIColor *_inactiveColor;
}

-(instancetype)initWithCoder:(NSCoder *)aDecoder {
  if ((self = [super initWithCoder:aDecoder])) {
      _quantum = 4;
      _isPlaying = NO;
      _tiles = [[NSMutableArray alloc] init];
      _backgroundColor = [UIColor colorWithRed:(CGFloat)0.25 green:(CGFloat)0.25 blue:(CGFloat)0.25 alpha:(CGFloat)1];
      _activeColor = [UIColor colorWithRed:(CGFloat)1 green:(CGFloat)0.835 blue:(CGFloat)0 alpha:(CGFloat)1];
      _activeBeginColor = [UIColor colorWithRed:(CGFloat)1 green:(CGFloat)0.416 blue:(CGFloat)0 alpha:(CGFloat)1];
      _inactiveColor = [UIColor colorWithRed:(CGFloat)0.7 green:(CGFloat)0.7 blue:(CGFloat)0.7 alpha:(CGFloat)1];
      [self layoutIfNeeded];
      [self setNeedsLayout];
  }
  return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self updateView]; // update view on rotation
}

- (void)setQuantum:(Float64)quantum {
    if (_quantum != quantum) {
        _quantum = quantum < 1 ? 1 : quantum;
        [self setNeedsLayout];
    }
}

- (void)setIsPlaying:(BOOL)isPlaying {
    _isPlaying = isPlaying;
}

- (void)setBeatTime:(Float64)beatTime {
    for (UIView *tile in _tiles) {
        tile.backgroundColor = _backgroundColor;
    }

    if (_isPlaying) {
        UIView *tile;
        NSUInteger currentQuanta;
        if (beatTime >= 0) {
            currentQuanta = (NSUInteger)(floor(fmod(beatTime, _quantum)));
            tile = [_tiles objectAtIndex:currentQuanta];
            tile.backgroundColor = currentQuanta == 0 ? _activeBeginColor : _activeColor;
        }
        else {
            currentQuanta = (NSUInteger)(floor(fmod(_quantum + beatTime, _quantum)));
            tile = [_tiles objectAtIndex:currentQuanta];
            tile.backgroundColor = _inactiveColor;
        }
    }
 }

- (void)updateView {
    if (_tiles != nil) {
        for (UIView *tile in _tiles) {
            [tile removeFromSuperview];
        }
        [_tiles removeAllObjects];
    }

    const CGFloat tileWidth =
        (self.bounds.size.width - kSpacing * ((CGFloat)_quantum - 1)) / (CGFloat)_quantum;

    NSUInteger numSegments = (NSUInteger)(ceil(_quantum));
    for (NSUInteger i = 0; i < numSegments; i++) {
        const CGFloat posX = i * (tileWidth + kSpacing);
        UIView *tile =
            [[UIView alloc] initWithFrame:CGRectMake(posX, 0, tileWidth, self.bounds.size.height)];
        tile.backgroundColor = _backgroundColor;
        tile.translatesAutoresizingMaskIntoConstraints = NO;
        [_tiles addObject:tile];
        [self addSubview:tile];
    }
}

@end
