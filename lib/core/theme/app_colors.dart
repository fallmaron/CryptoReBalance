import 'package:flutter/material.dart';

import '../../data/models/crypto_asset.dart';

abstract final class AppColors {
  static const background = Color(0xFF0B0F14);
  static const surface = Color(0xFF141A22);
  static const surfaceElevated = Color(0xFF1B2430);
  static const border = Color(0xFF2C394A);
  static const textPrimary = Color(0xFFE8EEF5);
  static const textSecondary = Color(0xFF8A97A8);
  static const accent = Color(0xFFE8B84A);
  static const accentDim = Color(0x33E8B84A);
  static const buy = Color(0xFF3DDC97);
  static const sell = Color(0xFFFF7A7A);
  static const danger = Color(0xFFFF6B6B);

  static const btc = Color(0xFFF7931A);
  static const hype = Color(0xFF2DE2C5);
  static const nexo = Color(0xFF4B8DF8);
  static const usdt = Color(0xFF26A17B);

  static Color forAsset(CryptoAsset asset) {
    return switch (asset) {
      CryptoAsset.btc => btc,
      CryptoAsset.hype => hype,
      CryptoAsset.nexo => nexo,
      CryptoAsset.usdt => usdt,
    };
  }
}
