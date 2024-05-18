#let cabs = [Alien是使用Rust编程语言所开发的一个操作系统。该系统融合了基于语言的隔离机制、使用代理接口和内存隔离以保证系统健壮性与安全性、支持系统各部分的动态加载与更换。Alien中使用的驱动程序完全使用安全的Rust代码编写以保证内存安全性。应用编译器保障的约束能够大幅减少由人脑保证约束可能带来的漏洞。在对驱动进行全面安全化之后，可以将其加入Alien或其他任一个操作系统该中，以提高系统整体的安全性。通过与不安全代码所编写的设备驱动相对比，测试对于读写性能有高要求的设备，可以看出驱动的安全化所影响的仅限于程序结构，而对性能几乎无负面影响。这证明了使用安全Rust代码编写驱动所带来的安全性提升不会伴随性能降低，具有实用价值。
]

#let ckw = ("Rust", "隔离", "驱动", "操作系统", "安全")

#let eabs = [Alien is an operating system developed using the Rust programming language. The system incorporates language-based isolation mechanisms, uses proxy interfaces and memory isolation for robustness and security, and supports dynamic loading and replacement of system components. drivers used in Alien are written entirely in safe Rust code for memory security. Applying compiler-guaranteed constraints dramatically reduces the vulnerability that can result from human-guaranteed constraints. After a driver is fully secured, it can be added to Alien or any other operating system to improve the overall security of the system. By testing devices with high read/write performance requirements against device drivers written in insecure code, it can be seen that driver securitization affects only the program structure, with little to no negative impact on performance. This demonstrates the practical value of using secure Rust code to write drivers with no performance degradation.]

#let ekw = ("Rust", "isolation", "driver", "OS", "safety")

#let ack = [
  值此论文完成之际，首先向我的导师陆慧梅老师，以及外校的向勇老师、吴竞邦老师致以最尊敬的谢意。没有他们长期对我的指点、督促及实验环境上的帮助，就没有本文中的成果。

  其次我要感谢陈林峰学长对我的帮助。他是Alien系统的主要开发者，为我的毕业设计提供了工作的方向，并且在我的研究过程中为我提供了环境配置、Alien系统相关等多方面的帮助。

  我还要感谢北京理工大学的众多教师和同学。经过这四年的学习、答疑和讨论，我才能够达到现在的水平。

  最后也要感谢我的父母养育我长大并供我上学，感谢北京理工大学为我提供学习的平台。感谢Rust编程语言、qemu模拟器、VirtIO虚拟设备以及许许多多的开发者，他们的工作是本项目的基础。感谢VSCode编辑器、Typst排版系统，为我的开发、论文撰写过程带来了极大的便利。
]