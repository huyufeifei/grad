#import "template/template.typ": *
#import "misc.typ": *

#show: doc => conf(
  cauthor: "罗博文",
  eauthor: "Bowen Luo",
  studentid: "1120203276",
  cheader: "",
  ctitle: "操作系统的驱动隔离改进与实现",
  etitle: "Driver Isolation Improvement and Implementation for Operating System",
  school: "计算机学院",
  cmajor: "计算机科学与技术",
  csupervisor: "陆慧梅",
  esupervisor: "",
  date: "2024年5月30日",
  cabstract: cabs,
  ckeywords: ckw,
  eabstract: eabs,
  ekeywords: ekw,
  acknowledgements: ack,
  blind: false,
  doc,
)

#include "ch1.typ"
#include "ch2.typ"
#include "ch3.typ"
#include "ch4.typ"
#include "ch5.typ"
#include "ch6.typ"

#pagebreak(weak: true)
#bibliography(("ref.yaml"))
// #bibliography(("ref.yaml"), style: "ieee")
// #pagebreak(weak: true)
// #appendix()
