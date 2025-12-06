from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, List, Optional


@dataclass
class SupplyOrder:
    id: int
    item: str
    qty: int
    cost: int
    eta: int
    remaining: float


ORDER_CATALOG: Dict[str, Dict[str, int]] = {
    "tests": {"label": "PCR Test Kits", "qty": 8, "cost": 1200, "eta": 6},
    "ppe": {"label": "PPE Crate", "qty": 20, "cost": 800, "eta": 4},
    "meds": {"label": "Medication Pack", "qty": 12, "cost": 1500, "eta": 8},
    "vaccines": {"label": "Vaccine Vials", "qty": 10, "cost": 2000, "eta": 10},
}


class SupplyChain:
    def __init__(self) -> None:
        self.stock: Dict[str, int] = {"tests": 10, "ppe": 30, "meds": 18, "vaccines": 6}
        self.orders: List[SupplyOrder] = []
        self.next_order_id = 1
        self.history: List[str] = []

    def consume(self, item: str, amount: int = 1) -> bool:
        if self.stock.get(item, 0) < amount:
            return False
        self.stock[item] -= amount
        return True

    def add_stock(self, item: str, amount: int) -> None:
        self.stock[item] = self.stock.get(item, 0) + amount

    def delay_orders(self, extra_hours: int) -> None:
        for order in self.orders:
            order.remaining += extra_hours

    def place_order(self, item: str) -> Optional[SupplyOrder]:
        template = ORDER_CATALOG.get(item)
        if not template:
            return None
        order = SupplyOrder(
            id=self.next_order_id,
            item=item,
            qty=template["qty"],
            cost=template["cost"],
            eta=template["eta"],
            remaining=float(template["eta"]),
        )
        self.next_order_id += 1
        self.orders.append(order)
        self.history.append(f"Ordered {template['label']} x{template['qty']}")
        return order

    def update(self, hours: int) -> None:
        for order in list(self.orders):
            order.remaining -= hours
            if order.remaining <= 0:
                self.add_stock(order.item, order.qty)
                self.orders.remove(order)

    def summary(self) -> Dict[str, object]:
        return {
            "stock": self.stock,
            "orders": [order.__dict__ for order in self.orders],
            "catalog": ORDER_CATALOG,
            "history": list(self.history[-8:]),
        }
