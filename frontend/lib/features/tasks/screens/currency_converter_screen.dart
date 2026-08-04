import 'package:currency_converter/currency.dart';
import 'package:currency_converter/currency_converter.dart';
import 'package:flutter/material.dart';

class CurrencyConverterScreen extends StatefulWidget {
  const CurrencyConverterScreen({super.key});

  @override
  State<CurrencyConverterScreen> createState() => _CurrencyConverterScreenState();
}

class _CurrencyConverterScreenState extends State<CurrencyConverterScreen> {
  String? usdToInr;
  Currency? myCurrency;

  @override
  void initState() {
    super.initState();
    convert();
  }

  void convert() async {
    // Always use NPR since the app budgets are in NPR
    myCurrency = Currency.npr;

    try {
      var usdConvert = await CurrencyConverter.convert(
        from: Currency.usd,
        to: myCurrency!,
        amount: 1,
        withoutRounding: true,
      );
      if (mounted) {
        setState(() {
          usdToInr = usdConvert?.toString() ?? "Error fetching rate";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          usdToInr = "API Error";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Money Convertor Example'),
        centerTitle: true,
      ),
      body: Container(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              "1 USD = ",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
            const SizedBox(
              width: 10,
            ),
            Expanded(
              child: Text(
                "$usdToInr ${myCurrency?.name.toUpperCase() ?? '...'}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: Colors.green,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
