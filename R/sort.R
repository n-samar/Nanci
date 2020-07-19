library(ggplot2, scales)
require(scales)
require(dplyr)
p<-read.csv("../data/sort.csv")
p<-p %>% select("size", "latency")

p<-ggplot(p, aes(x=as.numeric(paste(size)), y=as.numeric(paste(latency)), group=size)) +
	     geom_boxplot() +
	     xlab("Size [KB]") +
	     ylab("Latency per Element [us]") +
	     theme_bw() +
	     scale_x_log10(breaks=trans_breaks("log2", function(x) 2^x, n = 10),
	     labels=trans_format("log2", math_format(2^.x))) +
	     ggtitle(paste("qsort() on Mac (", toString(8), "B/elem)", sep="")) +
	     theme(plot.title = element_text(hjust = 0.5)) +
	     ylim(0, 0.3) +
	     theme(axis.text=element_text(size=12))	     

ggsave("../plots/sort.pdf", p, width=5, height=3, units="in", scale=1.5)

