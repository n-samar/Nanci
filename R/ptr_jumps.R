library(ggplot2, scales)
require(scales)
require(dplyr)
for (i in 1:10) {
    p<-read.csv("../data/ptr_jumps.csv")
    p<-transform(p, elem_size=as.numeric(paste(elem_size)))
    p<-dplyr::filter(p, elem_size==(2+i)*8) %>% select("size", "latency")

    p<-ggplot(p, aes(x=as.numeric(paste(size)), y=as.numeric(paste(latency)), group=size)) +
    	     geom_boxplot() +
	     xlab("Linked List Size [KB]") +
	     ylab("Latency per Node [us]") +
	     theme_bw() +
	     scale_x_log10(breaks=trans_breaks("log2", function(x) 2^x, n = 10),
	     					       labels=trans_format("log2", math_format(2^.x))) +
	     ggtitle(paste("Linked list traversal on Mac (", toString((2+i)*8), "B/elem)", sep="")) +
	     theme(plot.title = element_text(hjust = 0.5)) +
	     theme(axis.text=element_text(size=12))	     

     ggsave(paste("../plots/ptr_jumps_", i, ".pdf", sep=""),
     	    p, width=5, height=3, units="in", scale=1.5)
}


for (i in 1:10) {
    p<-read.csv("../data/ptr_jumps_seq.csv")
    p<-transform(p, elem_size=as.numeric(paste(elem_size)))
    p<-dplyr::filter(p, elem_size==(2+i)*8) %>% select("size", "latency")

    p<-ggplot(p, aes(x=as.numeric(paste(size)), y=as.numeric(paste(latency)), group=size)) +
    	     geom_boxplot() +
	     xlab("Linked List Size [KB]") +
	     ylab("Latency per Node [us]") +
	     theme_bw() +
	     ylim(0, 0.3) +
	     scale_x_log10(breaks=trans_breaks("log2", function(x) 2^x, n = 10),
	     					       labels=trans_format("log2", math_format(2^.x))) +
	     ggtitle(paste("Sequential array traversal on Mac (", toString((2+i)*8), "B/elem)", sep="")) +
	     theme(plot.title = element_text(hjust = 0.5)) +
	     theme(axis.text=element_text(size=12))	     

     ggsave(paste("../plots/ptr_jumps_seq_", i, ".pdf", sep=""),
     	    p, width=5, height=3, units="in", scale=1.5)
}