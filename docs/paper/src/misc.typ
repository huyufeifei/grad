#let cabs = [
  操作系统安全性由多方面综合构成，其中一个重要影响因素是驱动的安全性。本文通过使用基于Rust语言的内存隔离与保障机制来对设备驱动进行优化，应用编译器保障的约束并减少由人脑保证的约束，以此减少由开发者引入的漏洞。通过此方法被安全化的驱动可加入任一个操作系统该中，以提高该系统整体的安全性。将其以隔离域的形式加入Alien操作系统的分支后，在安全驱动和Alien的联合下，驱动能够支持故障隔离，防止在由硬件故障引起驱动崩溃时，操作系统本身全面停止运行。同时，还支持在崩溃发生时自动重新加载，在用户没有感知的情况下解决问题并恢复正常功能。

  通过与不安全代码所编写的设备驱动相对比，测试对于读写性能有高要求的设备，可以看出驱动的安全化所影响的仅限于程序结构，而对性能几乎无负面影响。这证明了使用安全Rust代码编写的驱动在功能上可以替换原有驱动，且所带来的安全性提升不会伴随性能降低的副作用，具有实用价值。
]

#let ckw = ("Rust", "隔离", "驱动", "操作系统", "安全")

#let eabs = [Operating system security consists of a combination of many aspects, one of the most important influencing factors is the security of the driver. In this paper, we optimize device drivers by using a memory isolation and security mechanism based on the Rust language, applying compiler-guaranteed constraints and reducing human-guaranteed constraints to reduce vulnerabilities introduced by developers. Drivers secured in this way can be added to any operating system to improve the overall security of that system. By adding it to an Alien OS branch as an isolation domain, the driver, in conjunction with the secure driver and Alien, can support fault isolation, preventing the OS itself from shutting down completely in the event of a driver crash caused by a hardware failure. It also supports automatic reloading when a crash occurs, solving the problem and restoring normal functionality without user perception.

  Comparing with the device driver written in unsafe code, and testing devices with high read/write performance requirements, it can be seen that the impact of driver securitization is limited to the program structure, and has almost no negative impact on the performance. This proves that drivers written in safe Rust code can functionally replace the original driver, and that the security enhancement will not be accompanied by the side effect of performance degradation, which is of practical value.]

#let ekw = ("Rust", "isolation", "driver", "OS", "safety")

#let ack = [
  值此论文完成之际，首先向我的导师陆慧梅老师，以及外校的向勇老师、吴竞邦老师致以最尊敬的谢意。没有他们长期对我的指点、督促及实验环境上的帮助，就没有本文中的成果。

  其次我要感谢陈林峰学长对我的帮助。他是Alien系统的主要开发者，为我的毕业设计提供了工作的方向，并且在我的研究过程中为我提供了环境配置、Alien系统相关等多方面的帮助。

  我还要感谢北京理工大学的众多教师和同学。经过这四年的学习、答疑和讨论，我才能够达到现在的水平。

  最后也要感谢我的父母养育我长大并供我上学，感谢北京理工大学为我提供学习的平台。感谢Rust编程语言、qemu模拟器、VirtIO虚拟设备以及许许多多的开发者，他们的工作是本项目的基础。感谢VSCode编辑器、Typst排版系统，为我的开发、论文撰写过程带来了极大的便利。
]