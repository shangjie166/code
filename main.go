package main

import (
"fmt"
"github.com/gin-gonic/gin"
"runtime/debug"
"time"
)

func main() {
	engine := gin.New()
	engine.GET("/boss/a", func(context *gin.Context) {
		start := time.Now()
		defer func() {
			end := time.Now()
			fmt.Println("timespan:", end.Sub(start))
			if e := recover(); e != nil {
				fmt.Println(debug.Stack())
			}
		}()

		time.Sleep(time.Second * 30)
		context.String(200, "request : "+context.Request.URL.RawQuery)
	})

	engine.Run(":20212")
}

