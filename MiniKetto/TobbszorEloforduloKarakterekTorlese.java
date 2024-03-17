import java.util.Scanner;
public class TobbszorEloforduloKarakterekTorlese {
    public static void main(String[] args) {
        Scanner scanner = new Scanner(System.in);

        System.out.println("szó:");
        String szo = scanner.nextLine();

        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < szo.length(); i++) {
            char karakter = szo.charAt(i);
            if (sb.indexOf(String.valueOf(karakter)) == -1) {
                sb.append(karakter);
            }
        }
        System.out.println("Többször törlés után: " + sb.toString());

        scanner.close();
    }
}
