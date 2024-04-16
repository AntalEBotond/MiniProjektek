import java.util.List;
import java.util.ArrayList;

public class Teszt {
    public static void main(String[] args) {
        try {
            NormalSzamla regularisSzamla = new NormalSzamla("Teszt");
            regularisSzamla.betesz(1000);
            regularisSzamla.kivesz(500);
            System.out.println(regularisSzamla);

            FolyoSzamla folyoSzamla = new FolyoSzamla("Teszt");
            folyoSzamla.betesz(2000);
            folyoSzamla.kivesz(1000);
            folyoSzamla.kivesz(1000);
            folyoSzamla.betesz(3000);
            System.out.println(folyoSzamla);

            TakarekSzamla takarekSzamla = new TakarekSzamla("Teszt", 5);
            takarekSzamla.betesz(10000);
            takarekSzamla.hozzaadKamat();
            System.out.println(takarekSzamla);

            int honap = 3;
            if (honap == 3) {
                List<TakarekSzamla> takarekSzamlak = new ArrayList<>();
                takarekSzamlak.add(takarekSzamla);
                kamatHozzaadas(takarekSzamlak);
                System.out.println("Havi kamatok hozzáadva");
            }

        } catch (InsufficientFundsException e) {
            System.out.println("Nincs elegendő összeg a számlán");
        }
    }

    private static void kamatHozzaadas(List<TakarekSzamla> takarekSzamlak) {
        for (TakarekSzamla szamla : takarekSzamlak) {
            szamla.hozzaadKamat();
        }
    }
}
