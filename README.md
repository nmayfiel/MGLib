# MGLib
A Miniature Graphics Library for Learning and Prototyping

## Getting Started
### Macos
```
cd /path/to/mg/lib && make
```
in your main
```
#include <mg.h>
```
C++ compilation example
```
clang++ my_main.cpp -Img/ -Lmg/ -lmg -framework AppKit -framework OpenGL
```

## Description
MGLib at its core, is a platform layer. MGLib interfaces with the underlying platform and exposes useful functions for drawing. MGLib doesn't really take a unique approach to hooking into the platform. The API is intentionally similar to some of the most popular open source graphics libraries in use today to make porting simpler.

'Robustness' and 'performance' and to a certain extent 'maintainability' were not considered to be first-order priorities in designing this library. Its purpose is simply to lower the bar of entry for novice programmers into graphics and platform interface code. As such, the value given first consideration here is readability, both on the user side, which requires a dead-simple API, and the library side, which requires a straight-forward implementation. Code in the library implementation is intended to be as informative as possible about what is going on. This means that the way in which much of the library is implemented would not be ideal for serious projects, but hopefully the simple design inspires some programmers who are new to graphics to dig into the source files.

On the other hand, a library which is dead-simple to use but can't run a graphics program smoothly is also not useful for learning. Personally, what piqued my interest about graphics programming in the first place was the challenge of drawing complex scenes with lots of vertices and textures at a high frame rate. Learning to use a library that is not at least capable of drawing a 2D game at 60fps would be a bummer, and would, in my opinion, not be worth the time to learn it. Thus, on some level, performance of the library is taken into account.

## Future Plans
* Documentation
* Font rendering
* Keyboard input
* Thread Safety
* OpenGL implementation on Windows
* DirectX 11 on Windows
* Gamepad input
* Ability to use custom shaders
* Optimization of performance
* Shippable version?

## Author
[Nickolas Mayfield](http://psdrndm.com)

## License
This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details

## Acknowledgements
* Thanks [Sean Barrett](https://github.com/nothings/stb) for stb_image.h 
* [42 Silicon Valley](http://42.us.org) for forcing me to use MiniLibX and inspiring me to create MGLib
