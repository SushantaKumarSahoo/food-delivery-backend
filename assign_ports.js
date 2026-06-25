const fs = require('fs');
const apps = [
  'user-service', 'auth-service', 'merchant-service', 'catalog-service', 
  'cart-service', 'order-service', 'payment-service', 'delivery-service'
];
let port = 3001;
for (const app of apps) {
  const p = `apps/${app}/src/main.ts`;
  let c = fs.readFileSync(p, 'utf8');
  c = c.replace(/listen\(3000/g, `listen(${port}`);
  c = c.replace(/port 3000/g, `port ${port}`);
  fs.writeFileSync(p, c);
  console.log(`${app} -> ${port}`);
  port++;
}
