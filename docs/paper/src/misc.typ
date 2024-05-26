#let cabs = [
  驱动程序漏洞与故障的频发为操作系统安全带来了重大威胁。本文探讨了一种新的安全驱动实现方案。通过使用基于Rust语言的内存隔离与保障机制，设计了可用于驱动程序与内核、设备交互的接口，进而使用纯粹的safe Rust实现了一系列驱动程序。这种安全设计能够有效地减少由开发者引入的漏洞。同时，考虑到模块化与复用性需求，驱动以Rust包的形式发布，能够在多种操作系统中简单引入，以提高系统整体的安全性。

  为测试其实用性，在Alien系统中以隔离域的形式加入该驱动。在操作系统的支持下，驱动能够满足故障隔离，防止硬件故障导致整个系统停止功能；同时，还支持在驱动崩溃发生时自动重新加载，在用户没有感知的情况下恢复正常功能。

  为测试其效率，在同样环境下将安全驱动与现有不安全驱动进行测试。结果表明驱动的安全化对性能几乎无负面影响。这证明了使用安全Rust代码编写的驱动在功能上可以替换原有驱动，在提升安全性的同时，不会带来性能减低的副作用。
]

#let ckw = ("Rust", "隔离", "驱动", "操作系统", "安全")

#let eabs = [The frequent occurrence of driver vulnerabilities and failures poses a major threat to operating system security. In this paper, we explore a new secure driver implementation scheme. By using a memory isolation and safeguard mechanism based on the Rust language, we design interfaces that can be used for drivers to interact with the kernel and devices, and then implement a series of drivers using pure safe Rust. This safe design can effectively reduce the vulnerabilities introduced by developers. At the same time, considering the modularity and reusability requirements, the driver is released in the form of Rust packages, which can be simply introduced in a variety of operating systems to improve the overall security of the system.

  In order to test its practicality, the driver is added to the Alien system in the form of an isolated domain. With the support of the operating system, the driver is able to meet the fault isolation to prevent hardware failure from causing the whole system to stop functioning; at the same time, it also supports automatic reloading when the driver crash occurs, restoring the normal functioning without the user's perception.
  
  To test its efficiency, the secured driver is tested against the existing insecure driver in the same environment. The results show that the securitization of the driver has almost no negative impact on performance. This proves that the driver written with secure Rust code can functionally replace the original driver and improve security without the side effect of performance degradation.]

#let ekw = ("Rust", "isolation", "driver", "OS", "safety")

#let ack = [
  值此论文完成之际，首先向我的导师陆慧梅老师，以及外校的向勇老师、吴竞邦老师致以最尊敬的谢意。没有他们长期对我的指点、督促及实验环境上的帮助，就没有本文中的成果。

  其次我要感谢陈林峰学长对我的帮助。他是Alien系统的主要开发者，为我的毕业设计提供了工作的方向，并且在我的研究过程中为我提供了环境配置、Alien系统相关等多方面的帮助。

  我还要感谢北京理工大学的众多教师和同学、同一实验室的同学和校外的众多好友。经过这四年和他们的学习、答疑和讨论，我才能够达到现在的水平。

  最后也要感谢我的父母养育我长大并供我上学，感谢北京理工大学为我提供学习的平台。感谢Rust编程语言、qemu模拟器、VirtIO虚拟设备以及许许多多的开发者，他们的工作是本项目的基础。感谢VSCode编辑器、Typst排版系统为我的开发、论文撰写过程带来了极大的便利。
]