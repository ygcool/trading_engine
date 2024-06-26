package admin

import (
	"encoding/json"

	"github.com/gin-gonic/gin"
	"github.com/yzimhao/trading_engine/cmd/haobase/base"
	"github.com/yzimhao/trading_engine/cmd/haobase/orders"
	"github.com/yzimhao/trading_engine/types/dbtables"
	"github.com/yzimhao/trading_engine/utils"
	"github.com/yzimhao/trading_engine/utils/app"
)

type tradlogSearch struct {
	Symbol string `json:"symbol"`
	Ask    string `json:"ask"`
	Bid    string `json:"bid"`
	AskUid string `json:"ask_uid"`
	BidUid string `json:"bid_uid"`
}

func TradeHistory(ctx *gin.Context) {
	db := app.Database().NewSession()
	defer db.Close()

	if ctx.Request.Method == "GET" {
		page := utils.S2Int(ctx.Query("page"))
		limit := utils.S2Int(ctx.Query("limit"))
		searchParams := ctx.Query("searchParams")

		var search tradlogSearch
		json.Unmarshal([]byte(searchParams), &search)

		if page <= 0 {
			page = 1
		}
		if limit <= 0 {
			limit = 10
		}
		offset := (page - 1) * limit

		data := []orders.TradeLog{}

		if search.Symbol == "" {
			for _, item := range base.NewTradeSymbol().All() {
				tb := &orders.Order{Symbol: item.Symbol}
				if dbtables.Exist(db, tb) {
					search.Symbol = item.Symbol
					break
				}
			}
		}

		tablename := &orders.TradeLog{Symbol: search.Symbol}
		q := db.Table(tablename)

		if search.Ask != "" {
			q = q.Where("ask=?", search.Ask)
		}
		if search.Bid != "" {
			q = q.Where("bid=?", search.Bid)
		}
		if search.AskUid != "" {
			q = q.Where("ask_uid=?", search.AskUid)
		}
		if search.BidUid != "" {
			q = q.Where("bid_uid=?", search.BidUid)
		}

		cond := q.Conds()
		err := q.OrderBy("id desc").Limit(limit, offset).Find(&data)
		if err != nil {
			render(ctx, 1, err.Error(), 0, "")
			return
		}

		total, _ := q.Table(tablename).And(cond).Count()

		cfg, _ := base.NewTradeSymbol().Get(search.Symbol)
		for i, _ := range data {
			data[i].FormatDecimal(cfg.PricePrecision, cfg.QtyPrecision)
		}

		if ctx.Query("api") == "1" {
			render(ctx, 0, "", int(total), data)
		} else {
			ctx.HTML(200, "user_trade_history", gin.H{
				"search":      search,
				"all_symbols": base.NewTradeSymbol().All(),
			})
		}
		return
	}
}
