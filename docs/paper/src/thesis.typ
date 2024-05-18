#import "template/template.typ": *
#import "misc.typ": *

#show: doc => conf(
  cauthor: "罗博文",
  eauthor: "Bowen Luo",
  studentid: "1120203276",
  cheader: "",
  ctitle: "基于Rust语言支持的单地址空间模块隔离方法",
  etitle: "Rust language-based modules compartmentalization for single address space operating system",
  school: "计算机学院",
  cmajor: "计算机科学与技术",
  csupervisor: "陆慧梅",
  esupervisor: "",
  date: "2024年5月17日",
  cabstract: cabs,
  ckeywords: ckw,
  eabstract: eabs,
  ekeywords: ekw,
  acknowledgements: ack,
  blind: true,
  doc,
)

#include "ch1.typ"
#include "ch2.typ"
#include "ch3.typ"
#include "ch4.typ"
#include "ch5.typ"

#pagebreak(weak: true)
#bibliography(("ref.yaml", "ref.bib"), style: "gb-7714-2015-note")
// #pagebreak(weak: true)
// #appendix()
