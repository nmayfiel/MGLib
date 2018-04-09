# MGLib
A Miniature Graphics Library for Learning

## Getting Started
### Macos
```
cd /path/to/mg/lib && make
```

## Description
At it's core, MGLib is a platform layer. It interfaces with the underlying platform and exposes useful functions for drawing. Robustness and performance were not considered to be first-order priorities in designing this library. It is intended to lower the bar of entry for students interested in learning graphics and platform interface code. This means that the value given first consideration here is readability, both on the user side, which requires a dead-simple API, and the library side, which requires a straight-forward implementation.

## Future Plans
* Documentation
* Keyboard input
* OpenGL implementation on Windows
* DirectX 11 on Windows
* Gamepad input
* Ability to use custom shaders
* Shippable version?

## License
This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details

## Acknowledgements
* Thanks [Sean Barrett](https://github.com/nothings/stb) for stb_image.h 
* [42 Silicon Valley](http://42.us.org) for forcing me to use MLX and inspiring me to create MGLib
