import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/features/cash/domain/pos_documents.dart';
import 'package:payk_ai_cfo_platform/features/cash/domain/pos_pricing.dart';
import 'package:payk_ai_cfo_platform/features/loyalty/domain/loyalty_models.dart';
import 'package:payk_ai_cfo_platform/features/showcase/domain/showcase_models.dart';

void main() {
  test('pos cart matches server cent rounding', () {
    final plain = pricePosCart(lines: const [PosPriceLine(qty: 2, price: 10)]);
    expect(plain.totalCents, 2000);

    final discounted = pricePosCart(
      lines: const [
        PosPriceLine(qty: 1, price: 10, discountPercent: 10),
        PosPriceLine(qty: 1.5, price: 10),
      ],
      receiptDiscountPercent: 5,
    );
    // 10.00 − 10% = 9.00; 1.5 × 10.00 = 15.00; чек −5% от 24.00 = 1.20.
    expect(discounted.receiptDiscountCents, 120);
    expect(discounted.totalCents, 2280);
    expect(moneyApi(22.8), '22.80');
    expect(qtyApi(1.5), '1.5');
    expect(qtyApi(2), '2');
  });

  test('receipt json keeps the number and return state', () {
    final receipt = PosReceipt.fromJson({
      'id': 7,
      'receipt_no': 14,
      'pos_kind': 'sale',
      'amount': '120.50',
      'payment_method': 'cash',
      'register_id': 3,
      'occurred_at': '2026-11-12T10:00:00Z',
      'lines_count': 1,
      'return_state': 'partial',
      'lines': [
        {
          'movement_id': 9,
          'kind': 'sale',
          'product_id': 4,
          'product_name': 'Нон',
          'qty': '2',
          'price': '10',
          'discount': '0',
          'amount': '20',
          'returned_qty': '1',
        },
      ],
    });
    expect(receipt.receiptNo, 14);
    expect(receipt.canAct, isTrue);
    expect(receipt.lines.single.leftQty, 1);
  });

  test('loyalty program and member parse the staff payload', () {
    final state = LoyaltyProgramState.fromJson({
      'program': {'id': 1, 'title': 'ПАЙК', 'slug': 'payk', 'enabled': true},
      'config': {'hold_days': 14},
      'terminals': [
        {
          'id': 2,
          'name': 'Касса 1',
          'format_code': 'SM',
          'is_active': true,
          'coin_enabled': true,
        },
      ],
      'members': 8,
    });
    expect(state.program?.slug, 'payk');
    expect(state.terminals.single.coinEnabled, isTrue);
    expect(state.members, 8);

    final preview = LoyaltyPosState.fromJson({
      'preview': {
        'id': 5,
        'state': 'pending',
        'format': 'SM',
        'amount': 100,
        'mode': 'earn_burn',
        'x': 2,
        'v': 4,
        'b': 4,
        'r': 0.5,
        'cash_to_pay': 95.5,
        'client_confirmed': true,
        'coupon': {'applied': true, 'amount': 10, 'offer': 10, 'usable': true},
      },
      'member': {
        'id': 3,
        'first_name': 'Али',
        'last_name': 'Р',
        'phone': '992***',
        'status': 2,
        'balance': 12,
        'segment': 'AB',
        'is_regular': true,
        'wholesale_flag': 'pending',
      },
    });
    expect(preview.preview.priced, isTrue);
    expect(preview.preview.coupon.applied, isTrue);
    expect(preview.member.segment, 'AB');
    expect(preview.member.isRegular, isTrue);

    final dash = LoyaltyDashboard.fromJson({
      'members': {
        'total': 10,
        'new': 2,
        'by_status': {'1': 8},
      },
      'bills': {'count': 4, 'amount': 400, 'average': 100},
      'cashback': {'accrued': 8, 'burned': 1},
      'liability': {'balance': 20, 'debt': 0},
      'gifts': {
        'coupons': {'used_amount': 15},
        'dob_bonus': {'amount': 10},
      },
      'segments': {
        '30': {
          'matrix': {
            'AA': {'members': 3},
          },
        },
      },
    });
    expect(dash.membersTotal, 10);
    expect(dash.segments['AA'], 3);
    expect(dash.couponUsed, 15);
  });

  test('showcase card keeps both languages', () {
    final card = ShowcaseCard.fromJson({
      'id': 1,
      'title_tj': 'Тоҷикӣ',
      'title_ru': 'Русский',
      'text_tj': '',
      'text_ru': '',
      'art': 'gem',
      'is_active': true,
      'state': 'live',
      'views': 4,
      'leads': 1,
    });
    expect(card.title('tg'), 'Тоҷикӣ');
    expect(card.title('ru'), 'Русский');
    expect(card.state, 'live');
    expect(card.toInput()['art'], 'gem');
  });
}
